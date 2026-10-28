using System.Globalization;
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
    IHouseMutationCoordinator mutations, ISupplyOrderEmailSender email, TimeProvider clock,
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
                if (previous.Workflow != SupplyOrderWorkflow.SIMPLE_CONTACT || previous.RequestFingerprint != fingerprint)
                    throw new ConflictException("This request ID belongs to a different order.");
                return SupplyOrderService.Map(previous);
            }
            EnsureEmailConfigured();
            var supplier = await store.SupplierAsync(request.SupplierId, ct) ?? throw new NotFoundException("Supplier not found.");
            if (supplier.HouseId.HasValue && supplier.HouseId != house) throw new NotFoundException("Supplier not found.");
            if (!supplier.Active || !new System.ComponentModel.DataAnnotations.EmailAddressAttribute().IsValid(supplier.Email))
                throw new ConflictException("The supplier email is not available. You can call the supplier instead.");
            var now = clock.GetUtcNow().UtcDateTime;
            var order = new SupplyOrder { Id = Guid.NewGuid(), HouseId = house, CreatorUserId = actor, PayerUserId = actor,
                ClientRequestId = request.ClientRequestId, SupplierId = supplier.Id, SupplierName = supplier.Name,
                SupplierPhone = supplier.Phone, SupplierEmail = supplier.Email.Trim(), DeliveryFee = supplier.DeliveryFee,
                DeliveryAddress = request.DeliveryAddress.Trim(), ContactPhone = request.ContactPhone.Trim(), Note = request.Note.Trim(),
                RequestFingerprint = fingerprint, Workflow = SupplyOrderWorkflow.SIMPLE_CONTACT,
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
            var member = await uow.HouseMembers.GetByHouseAndUserIdAsync(house, actor, ct);
            var body = new StringBuilder().AppendLine($"Household order {order.Id}").AppendLine($"Ordered by: {member!.User.DisplayName}");
            foreach (var line in order.Lines) body.AppendLine($"{line.Quantity} x {line.Name} ({line.Unit}) - {line.UnitPrice.ToString("0", CultureInfo.InvariantCulture)} VND each");
            body.AppendLine($"Delivery fee: {order.DeliveryFee:0} VND").AppendLine($"Total: {order.Total:0} VND")
                .AppendLine($"Address: {order.DeliveryAddress}").AppendLine($"Phone: {order.ContactPhone}").AppendLine($"Note: {order.Note}");
            order.EmailDispatch = new() { Id = Guid.NewGuid(), OrderId = order.Id, Recipient = order.SupplierEmail,
                Subject = $"Household order {order.Id}", Body = body.ToString(), CreatedAt = now };
            order.Activities.Add(new() { Id = Guid.NewGuid(), OrderId = order.Id, ActorUserId = actor, Kind = OrderEmailState.Queued, RecordedAt = now });
            store.Add(order);
            return SupplyOrderService.Map(order);
        }, ct);
    }

    public Task<SupplyOrderResponse> RetryEmailAsync(Guid house, Guid id, Guid actor, CancellationToken ct) => mutations.RunAsync(house, async () =>
    {
        await Access(house, actor, ct);
        var order = await OwnedOrder(house, id, actor, ct);
        EnsureEmailConfigured();
        var dispatch = order.EmailDispatch ?? throw new ConflictException("No email request exists.");
        if (dispatch.State is OrderEmailState.Failed or OrderEmailState.Unknown)
        {
            dispatch.State = OrderEmailState.Queued; dispatch.ErrorCode = null; dispatch.LeaseUntil = null; dispatch.LeaseId = null;
            var activity = new SupplyOrderActivity { Id = Guid.NewGuid(), OrderId = id, ActorUserId = actor, Kind = OrderEmailState.Queued, RecordedAt = clock.GetUtcNow().UtcDateTime };
            order.Activities.Add(activity); store.Add(activity);
        }
        return SupplyOrderService.Map(order);
    }, ct);

    public async Task<SupplyOrderResponse> RecordPaymentAsync(Guid house, Guid id, Guid actor, RecordSupplyOrderPaymentRequest request, CancellationToken ct)
    {
        await paymentValidator.ValidateAndThrowAsync(request, ct);
        return await mutations.RunAsync(house, async () =>
        {
            await Access(house, actor, ct);
            var order = await OwnedOrder(house, id, actor, ct);
            if (order.PaymentRecordRequestId.HasValue)
            {
                if (order.PaymentRecordRequestId == request.ClientRequestId && order.RecordedPaidAmount == request.Amount && order.PaymentReference == request.Reference.Trim())
                    return SupplyOrderService.Map(order);
                throw new ConflictException("Payment was already recorded. Do not record it again.");
            }
            if (order.Status != SupplyOrderStatus.DRAFT || order.EmailDispatch?.State != OrderEmailState.Sent)
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

    private void EnsureEmailConfigured()
    {
        if (!email.IsConfigured) throw new ConflictException("Order email is not configured yet. You can call the supplier instead.");
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
        if (order.Workflow != SupplyOrderWorkflow.SIMPLE_CONTACT) throw new ConflictException("Use the original workflow for this purchase.");
        return order;
    }
}
