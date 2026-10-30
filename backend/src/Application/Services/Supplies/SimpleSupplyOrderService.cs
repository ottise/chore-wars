using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using FluentValidation;

namespace ChoreWars.Application.Services.Supplies;

public sealed class SimpleSupplyOrderService(ISupplyRepository store, IUnitOfWork uow, IHouseAccessService access,
    IHouseMutationCoordinator mutations, TimeProvider clock,
    IValidator<SendSupplyOrderRequest> sendValidator, IValidator<RecordSupplyOrderPaymentRequest> paymentValidator) : ISimpleSupplyOrderService
{
    public async Task<SupplyOrderResponse> SendAsync(Guid house, Guid actor, SendSupplyOrderRequest request, CancellationToken ct)
    {
        await sendValidator.ValidateAndThrowAsync(request, ct);
        return await mutations.RunAsync(house, async () =>
        {
            await Access(house, actor, ct);
            var fingerprint = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(request))));
            var previous = await store.RequestAsync(house, actor, request.ClientRequestId, ct);
            if (previous != null)
            {
                if (previous.Workflow != SupplyOrderWorkflow.SIMPLE_SMS || previous.RequestFingerprint != fingerprint)
                    throw new ConflictException("This request ID belongs to a different order.");
                return SupplyOrderService.Map(previous);
            }
            var supplier = await store.SupplierAsync(request.SupplierId, ct) ?? throw new NotFoundException("Supplier not found.");
            if (supplier.HouseId.HasValue && supplier.HouseId != house) throw new NotFoundException("Supplier not found.");
            if (!supplier.Active) throw new ConflictException("This supplier is not available.");
            if (string.IsNullOrWhiteSpace(supplier.Phone)) throw new ConflictException("Add a supplier phone number before preparing an SMS order.");
            var now = clock.GetUtcNow().UtcDateTime;
            var order = new SupplyOrder { Id = Guid.NewGuid(), HouseId = house, CreatorUserId = actor, PayerUserId = actor,
                ClientRequestId = request.ClientRequestId, SupplierId = supplier.Id, SupplierName = supplier.Name,
                SupplierPhone = supplier.Phone, SupplierEmail = supplier.Email.Trim(), DeliveryFee = supplier.DeliveryFee,
                DeliveryAddress = request.DeliveryAddress.Trim(), ContactPhone = request.ContactPhone.Trim(), Note = request.Note.Trim(),
                RequestFingerprint = fingerprint, Workflow = SupplyOrderWorkflow.SIMPLE_SMS,
                CreatedVia = request.ViaAI ? SupplyOrderCreatedVia.AI : SupplyOrderCreatedVia.MANUAL,
                CreatedAt = now, QuoteExpiresAt = now.AddMinutes(SupplyConstants.QuoteMinutes) };
            foreach (var line in request.Lines.OrderBy(x => x.ProductId))
            {
                var product = await store.ProductAsync(line.ProductId, ct) ?? throw new NotFoundException("Product not found.");
                if (!product.Active || product.SupplierId != supplier.Id || product.AvailableQuantity < line.Quantity)
                    throw new ConflictException("An item is not available in the requested quantity.");
                order.Lines.Add(new() { Id = Guid.NewGuid(), OrderId = order.Id, ProductId = product.Id,
                    Name = product.Name, Unit = product.Unit, UnitPrice = product.Price, Quantity = line.Quantity });
            }
            order.Total = order.Lines.Sum(x => x.Quantity * x.UnitPrice) + order.DeliveryFee;
            if (order.Total <= 0 || order.Total > SupplyConstants.MaxMoney) throw new DomainException("Invalid order total.");
            var requestedShares = request.Shares is { Count: > 0 }
                ? request.Shares
                : [new OrderCostShareRequest(actor)];
            if (requestedShares.Count > SupplyConstants.MaxMembers ||
                requestedShares.Select(x => x.UserId).Distinct().Count() != requestedShares.Count ||
                !requestedShares.Any(x => x.UserId == actor))
                throw new DomainException("Choose unique household members including the person paying.");
            if (requestedShares.Any(x => x.Amount.HasValue) && requestedShares.Any(x => !x.Amount.HasValue))
                throw new DomainException("Specify every member's share or split the total equally.");
            var amounts = requestedShares.All(x => !x.Amount.HasValue)
                ? SupplyCostSplitter.Split(order.Total, requestedShares.Select(x => x.UserId).ToList())
                : requestedShares.ToDictionary(x => x.UserId, x => x.Amount!.Value);
            if (amounts.Values.Sum() != order.Total)
                throw new DomainException("Member shares must add up to the exact order total.");
            foreach (var share in requestedShares)
            {
                await access.EnsureActiveAsync(house, share.UserId, ct);
                var member = await uow.HouseMembers.GetByHouseAndUserIdAsync(house, share.UserId, ct)
                    ?? throw new ForbiddenException("A selected household member is no longer active.");
                order.Shares.Add(new OrderCostShare
                {
                    Id = Guid.NewGuid(), OrderId = order.Id, UserId = share.UserId,
                    DisplayName = member.User.DisplayName, Amount = amounts[share.UserId]
                });
            }
            order.Activities.Add(new() { Id = Guid.NewGuid(), OrderId = order.Id, ActorUserId = actor, Kind = "SMS_PREPARED", RecordedAt = now });
            store.Add(order);
            return SupplyOrderService.Map(order);
        }, ct);
    }

    public Task<SupplyOrderResponse> RetryEmailAsync(Guid house, Guid id, Guid actor, CancellationToken ct) => mutations.RunAsync<SupplyOrderResponse>(house, async () =>
    {
        await Access(house, actor, ct);
        await OwnedOrder(house, id, actor, ct);
        throw new ConflictException("Supplier email has been retired. Contact the supplier by phone or SMS.");
    }, ct);

    public async Task<SupplyOrderResponse> RecordPaymentAsync(Guid house, Guid id, Guid actor, RecordSupplyOrderPaymentRequest request, CancellationToken ct)
    {
        await paymentValidator.ValidateAndThrowAsync(request, ct);
        return await mutations.RunAsync(house, async () =>
        {
            await Access(house, actor, ct);
            var order = await OwnedOrder(house, id, actor, ct);
            if (order.Workflow is SupplyOrderWorkflow.SIMPLE_SMS or SupplyOrderWorkflow.SIMPLE_CONTACT)
                throw new ConflictException("Payment must be verified by PayOS. Open the order and choose Pay with PayOS.");
            if (order.PaymentRecordRequestId.HasValue)
            {
                if (order.PaymentRecordRequestId == request.ClientRequestId && order.RecordedPaidAmount == request.Amount && order.PaymentReference == request.Reference.Trim())
                    return SupplyOrderService.Map(order);
                throw new ConflictException("Payment was already recorded. Do not record it again.");
            }
            if (order.Status != SupplyOrderStatus.DRAFT || (order.Workflow != SupplyOrderWorkflow.SIMPLE_SMS && order.EmailDispatch?.State != OrderEmailState.Sent))
                throw new ConflictException("Send the order successfully before recording payment.");
            if ((await store.PaymentsAsync(id, ct)).Count != 0) throw new ConflictException("Reconcile the existing online payment first.");
            var now = clock.GetUtcNow().UtcDateTime;
            order.PaymentRecordRequestId = request.ClientRequestId; order.PaymentRecordedByUserId = actor;
            order.RecordedPaidAmount = request.Amount; order.PaymentConfirmationSource = OrderEmailState.UserReported;
            order.PaymentReference = request.Reference.Trim(); order.PaymentRecordedAt = now; order.PaidAt = now;
            order.Status = SupplyOrderStatus.PAID; order.Version++;
            var activity = new SupplyOrderActivity { Id = Guid.NewGuid(), OrderId = id, ActorUserId = actor, Kind = OrderEmailState.UserReported,
                Amount = request.Amount, RecordedAt = now, Reference = order.PaymentReference };
            order.Activities.Add(activity); store.Add(activity);
            return SupplyOrderService.Map(order);
        }, ct);
    }

    private async Task Access(Guid house, Guid actor, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct); await access.EnsureWritableAsync(house, ct);
    }
    private async Task<SupplyOrder> OwnedOrder(Guid house, Guid id, Guid actor, CancellationToken ct)
    {
        var order = await store.OrderAsync(id, ct) ?? throw new NotFoundException("Order not found.");
        if (order.HouseId != house) throw new NotFoundException("Order not found.");
        if (order.CreatorUserId != actor) throw new ForbiddenException("Only the person who placed this order can change it.");
        if (order.Workflow is not (SupplyOrderWorkflow.SIMPLE_CONTACT or SupplyOrderWorkflow.SIMPLE_SMS)) throw new ConflictException("Use the original workflow for this purchase.");
        return order;
    }
}
