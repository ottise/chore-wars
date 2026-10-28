using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using FluentValidation;

namespace ChoreWars.Application.Services.Supplies;

public sealed class SupplyOrderService(ISupplyRepository store, IUnitOfWork uow, IHouseAccessService access,
    IHouseMutationCoordinator mutations, IEventPublisher events, TimeProvider clock,
    IValidator<CreateSupplyOrderRequest> validator) : ISupplyOrderService
{
    public static SupplyOrderResponse Map(SupplyOrder o) => new(o.Id, o.HouseId, o.SupplierId, o.SupplierName,
        o.SupplierPhone, o.CreatorUserId, o.PayerUserId, o.Status.ToString(), o.CreatedVia.ToString(), o.Version,
        o.DeliveryAddress, o.ContactPhone, o.Total, o.DeliveryFee, o.RefundedAmount, o.QuoteExpiresAt, o.CreatedAt,
        o.Lines.Select(x => new SupplyOrderLineResponse(x.ProductId, x.Name, x.Unit, x.UnitPrice, x.Quantity)).ToList(),
        o.Shares.Select(x => new OrderCostShareResponse(x.UserId, x.DisplayName, x.Amount, x.ApprovedAt.HasValue, x.RejectedAt.HasValue)).ToList(),
        o.Workflow.ToString(), o.SupplierEmail, o.EmailDispatch?.State ?? OrderEmailState.NotRequested, o.EmailDispatch?.ErrorCode,
        o.EmailDispatch?.SentAt, o.RecordedPaidAmount, o.PaymentRecordedByUserId, o.PaymentRecordedAt,
        o.PaymentConfirmationSource, o.PaymentReference, o.Note,
        o.Activities.OrderBy(x => x.RecordedAt).ThenBy(x => x.Id).Select(x => new SupplyOrderActivityResponse(x.Kind, x.ActorUserId, x.RecordedAt, x.Amount, x.Reference)).ToList());

    public async Task<List<SupplyOrderResponse>> ListAsync(Guid house, Guid actor, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct);
        return (await store.OrdersAsync(house, null, ct)).Select(Map).ToList();
    }

    public async Task<SupplyOrderResponse> ReadAsync(Guid house, Guid id, Guid actor, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct);
        return Map(await OrderAsync(house, id, ct));
    }

    public async Task<SupplyOrderResponse> CreateAsync(Guid house, Guid actor, CreateSupplyOrderRequest request, CancellationToken ct)
    {
        await validator.ValidateAndThrowAsync(request, ct);
        return await mutations.RunAsync(house, async () =>
        {
            await access.EnsureActiveAsync(house, actor, ct);
            await access.EnsureWritableAsync(house, ct);
            var fingerprint = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(request))));
            var existing = await store.RequestAsync(house, actor, request.ClientRequestId, ct);
            if (existing != null)
            {
                if (existing.RequestFingerprint != fingerprint) throw new ConflictException("This request ID was already used for a different order.");
                return Map(existing);
            }
            var order = await BuildDraftAsync(house,actor,request,fingerprint,ct);
            store.Add(order);
            return Map(order);
        }, ct);
    }


    private async Task<SupplyOrder> BuildDraftAsync(Guid house,Guid actor,CreateSupplyOrderRequest request,string fingerprint,CancellationToken ct)
    {
            var supplier = await store.SupplierAsync(request.SupplierId, ct) ?? throw new NotFoundException("Supplier not found.");
            if (!supplier.Active) throw new ConflictException("This supplier is unavailable.");
            var now = clock.GetUtcNow().UtcDateTime;
            var order = new SupplyOrder
            {
                Id = Guid.NewGuid(), HouseId = house, CreatorUserId = actor, ClientRequestId = request.ClientRequestId,
                PayerUserId = request.PayerUserId, SupplierId = supplier.Id, SupplierName = supplier.Name,
                SupplierPhone = supplier.Phone, DeliveryFee = supplier.DeliveryFee, RequestFingerprint = fingerprint,
                DeliveryAddress = request.DeliveryAddress.Trim(), ContactPhone = request.ContactPhone.Trim(),
                CreatedAt = now, QuoteExpiresAt = now.AddMinutes(SupplyConstants.QuoteMinutes),
                CreatedVia = request.ViaAI ? SupplyOrderCreatedVia.AI : SupplyOrderCreatedVia.MANUAL
            };
            foreach (var line in request.Lines.OrderBy(x => x.ProductId))
            {
                var p = await store.ProductAsync(line.ProductId, ct) ?? throw new NotFoundException("Product not found.");
                if (p.SupplierId != supplier.Id || !p.Active || p.AvailableQuantity < line.Quantity)
                    throw new ConflictException($"{p.Name} is unavailable in the requested quantity.");
                order.Lines.Add(new SupplyOrderLine { Id = Guid.NewGuid(), OrderId = order.Id, ProductId = p.Id,
                    Name = p.Name, Unit = p.Unit, UnitPrice = p.Price, Quantity = line.Quantity });
            }
            order.Total = order.Lines.Sum(x => x.UnitPrice * x.Quantity) + order.DeliveryFee;
            if (order.Total <= 0 || order.Total > SupplyConstants.MaxMoney) throw new DomainException("Invalid order total.");
            var equal = request.Shares.All(x => x.Amount == null);
            if (!equal && request.Shares.Any(x => x.Amount == null)) throw new DomainException("Specify every share or split all shares equally.");
            var amounts = equal ? SupplyCostSplitter.Split(order.Total, request.Shares.Select(x => x.UserId).ToList())
                : request.Shares.ToDictionary(x => x.UserId, x => x.Amount!.Value);
            if (amounts.Values.Sum() != order.Total) throw new DomainException("Shares must add up to the exact order total.");
            foreach (var share in request.Shares)
            {
                await access.EnsureActiveAsync(house, share.UserId, ct);
                var member = await uow.HouseMembers.GetByHouseAndUserIdAsync(house, share.UserId, ct);
                order.Shares.Add(new OrderCostShare { Id = Guid.NewGuid(), OrderId = order.Id, UserId = share.UserId,
                    DisplayName = member!.User.DisplayName, Amount = amounts[share.UserId] });
            }
            return order;
    }

    public async Task<SupplyOrderResponse> ReviseAsync(Guid house,Guid id,Guid actor,ReviseSupplyOrderRequest revision,CancellationToken ct)
    {
        await validator.ValidateAndThrowAsync(revision.Draft,ct);
        return await mutations.RunAsync(house,async()=>{
            await access.EnsureActiveAsync(house,actor,ct);await access.EnsureWritableAsync(house,ct);
            var o=await OrderAsync(house,id,ct);if(o.CreatorUserId!=actor)throw new ForbiddenException("Only the creator can revise this purchase.");
            var fingerprint=Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(revision.Draft))));
            if(o.LastRevisionRequestId==revision.Draft.ClientRequestId){if(o.RequestFingerprint!=fingerprint)throw new ConflictException("Revision request ID already used.");return Map(o);}
            CheckVersion(o,revision.ExpectedVersion);
            if(o.Status is not (SupplyOrderStatus.DRAFT or SupplyOrderStatus.AWAITING_APPROVAL or SupplyOrderStatus.APPROVED))throw new ConflictException("Only unpaid purchases can be revised.");
            if((await store.PaymentsAsync(id,ct)).Count>0)throw new ConflictException("Reconcile an existing checkout before revising a purchase.");
            if(o.StockReserved){foreach(var line in o.Lines.OrderBy(x=>x.ProductId))await store.ReleaseAsync(line.ProductId,line.Quantity,ct);o.StockReserved=false;}
            var updated=await BuildDraftAsync(house,actor,revision.Draft,fingerprint,ct);
            if(o.ProposalId.HasValue){var proposal=await uow.ActionProposals.GetByIdForUpdateAsync(o.ProposalId.Value,ct);if(proposal!=null)proposal.Status=ProposalStatus.CANCELLED;}
            o.SupplierId=updated.SupplierId;o.SupplierName=updated.SupplierName;o.SupplierPhone=updated.SupplierPhone;o.DeliveryFee=updated.DeliveryFee;
            o.PayerUserId=updated.PayerUserId;o.DeliveryAddress=updated.DeliveryAddress;o.ContactPhone=updated.ContactPhone;o.Total=updated.Total;o.QuoteExpiresAt=updated.QuoteExpiresAt;
            foreach(var old in o.Lines.Where(x=>updated.Lines.All(n=>n.ProductId!=x.ProductId)).ToList())o.Lines.Remove(old);
            foreach(var line in updated.Lines){var old=o.Lines.SingleOrDefault(x=>x.ProductId==line.ProductId);if(old==null){line.OrderId=o.Id;o.Lines.Add(line);}else{old.Name=line.Name;old.Unit=line.Unit;old.UnitPrice=line.UnitPrice;old.Quantity=line.Quantity;}}
            foreach(var old in o.Shares.Where(x=>updated.Shares.All(n=>n.UserId!=x.UserId)).ToList())o.Shares.Remove(old);
            foreach(var share in updated.Shares){var old=o.Shares.SingleOrDefault(x=>x.UserId==share.UserId);if(old==null){share.OrderId=o.Id;o.Shares.Add(share);}else{old.Amount=share.Amount;old.DisplayName=share.DisplayName;old.ApprovedAt=null;old.RejectedAt=null;}}
            o.Status=SupplyOrderStatus.DRAFT;o.ProposalId=null;o.RequestFingerprint=fingerprint;o.LastRevisionRequestId=revision.Draft.ClientRequestId;o.Version++;
            return Map(o);
        },ct);
    }

    public Task<SupplyOrderResponse> SubmitAsync(Guid house, Guid id, Guid actor, int version, CancellationToken ct) =>
        mutations.RunAsync(house, async () =>
        {
            await access.EnsureActiveAsync(house, actor, ct);
            await access.EnsureWritableAsync(house, ct);
            var order = await OrderAsync(house, id, ct);
            if (order.CreatorUserId != actor) throw new ForbiddenException("Only the creator can submit this draft.");
            if (order.Status == SupplyOrderStatus.AWAITING_APPROVAL) return Map(order);
            CheckVersion(order, version);
            if (order.Status != SupplyOrderStatus.DRAFT) throw new ConflictException("This order is no longer a draft.");
            CheckQuote(order);
            var room = await uow.Chats.GetRoomByHouseIdAsync(house, ct);
            if (room == null)
            {
                room = new ChatRoom { Id = Guid.NewGuid(), HouseId = house, CreatedAt = clock.GetUtcNow().UtcDateTime };
                await uow.Chats.AddRoomAsync(room, ct);
            }
            var proposal = new ActionProposal { Id = Guid.NewGuid(), HouseId = house, RoomId = room.Id,
                CreatorId = actor, Type = ProposalType.SUPPLY_PURCHASE, Status = ProposalStatus.PENDING,
                Title = "Household supplies purchase", Description = $"Review your share of {order.Total:N0} VND before checkout.",
                PayloadJson = JsonSerializer.Serialize(new { orderId = order.Id, version = order.Version + 1 }),
                CreatedAt = clock.GetUtcNow().UtcDateTime, ExpiresAt = order.QuoteExpiresAt,
                Confirmations = order.Shares.Select(s => new ProposalConfirmation { Id = Guid.NewGuid(), TargetUserId = s.UserId }).ToList() };
            foreach (var c in proposal.Confirmations) c.ProposalId = proposal.Id;
            await uow.ActionProposals.AddAsync(proposal, ct);
            order.ProposalId = proposal.Id;
            order.Status = SupplyOrderStatus.AWAITING_APPROVAL;
            order.Version++;
            await Notify(order, actor, null, "Review purchase", "Please approve your share. No payment has been made.", ct);
            return Map(order);
        }, ct);

    public Task<SupplyOrderResponse> DecideAsync(Guid house, Guid id, Guid actor, SupplyDecisionRequest request, CancellationToken ct) =>
        mutations.RunAsync(house, async () =>
        {
            await access.EnsureActiveAsync(house, actor, ct);
            await access.EnsureWritableAsync(house, ct);
            var order = await OrderAsync(house, id, ct);
            var share = order.Shares.SingleOrDefault(x => x.UserId == actor) ?? throw new ForbiddenException("You are not a participant in this purchase.");
            if (request.Approve && share.ApprovedAt.HasValue) return Map(order);
            CheckVersion(order, request.ExpectedVersion);
            CheckQuote(order);
            if (order.Status != SupplyOrderStatus.AWAITING_APPROVAL) throw new ConflictException("This order is not awaiting approval.");
            var now = clock.GetUtcNow().UtcDateTime;
            if (request.Approve) share.ApprovedAt = now; else share.RejectedAt = now;
            var proposal = order.ProposalId.HasValue ? await uow.ActionProposals.GetByIdForUpdateAsync(order.ProposalId.Value, ct) : null;
            var confirmation = proposal?.Confirmations.Single(x => x.TargetUserId == actor);
            if (confirmation != null) { confirmation.Status = request.Approve ? ConfirmationStatus.CONFIRMED : ConfirmationStatus.REJECTED; confirmation.RespondedAt = now; }
            if (!request.Approve) { order.Status = SupplyOrderStatus.CANCELLED; if (proposal != null) proposal.Status = ProposalStatus.REJECTED; }
            else if (order.Shares.All(x => x.ApprovedAt.HasValue))
            {
                foreach (var s in order.Shares) await access.EnsureActiveAsync(house, s.UserId, ct);
                foreach (var line in order.Lines.OrderBy(x => x.ProductId)) await store.ReserveAsync(line.ProductId, line.Quantity, ct);
                order.StockReserved = true;
                order.Status = SupplyOrderStatus.APPROVED;
                if (proposal != null) proposal.Status = ProposalStatus.APPROVED;
            }
            order.Version++;
            await Notify(order, actor, order.PayerUserId, request.Approve ? "Purchase approval updated" : "Purchase declined",
                order.Status == SupplyOrderStatus.APPROVED ? "Everyone approved. The designated payer can now checkout." : "Open the purchase to see the latest decision.", ct);
            return Map(order);
        }, ct);

    public Task<SupplyOrderResponse> CancelAsync(Guid house, Guid id, Guid actor, int version, CancellationToken ct) =>
        mutations.RunAsync(house, async () =>
        {
            await access.EnsureActiveAsync(house, actor, ct);
            var o = await OrderAsync(house, id, ct);
            if (actor != o.CreatorUserId && actor != o.PayerUserId) throw new ForbiddenException();
            if (o.Status == SupplyOrderStatus.CANCELLED) return Map(o);
            CheckVersion(o, version);
            if (o.Status is not (SupplyOrderStatus.DRAFT or SupplyOrderStatus.AWAITING_APPROVAL or SupplyOrderStatus.APPROVED))
                throw new ConflictException("Paid orders require a supplier refund, not cancellation.");
            if ((await store.PaymentsAsync(o.Id, ct)).Any(x => x.Status is SupplierPaymentStatus.CREATING or SupplierPaymentStatus.PENDING))
                throw new ConflictException("A checkout is pending. Reconcile it before cancelling.");
            if (o.StockReserved) { foreach (var line in o.Lines.OrderBy(x => x.ProductId)) await store.ReleaseAsync(line.ProductId, line.Quantity, ct); o.StockReserved = false; }
            o.Status = SupplyOrderStatus.CANCELLED; o.Version++;
            if (o.ProposalId.HasValue) { var p = await uow.ActionProposals.GetByIdForUpdateAsync(o.ProposalId.Value, ct); if (p != null) p.Status = ProposalStatus.CANCELLED; }
            return Map(o);
        }, ct);

    public Task<SupplyOrderResponse> ReceiveAsync(Guid house, Guid id, Guid actor, int version, CancellationToken ct) =>
        mutations.RunAsync(house, async () =>
        {
            await access.EnsureActiveAsync(house, actor, ct);
            var o = await OrderAsync(house, id, ct);
            if (actor != o.PayerUserId && actor != o.CreatorUserId) throw new ForbiddenException();
            if (o.Status == SupplyOrderStatus.COMPLETED) return Map(o);
            CheckVersion(o, version);
            if (o.Status != SupplyOrderStatus.DELIVERED) throw new ConflictException("Wait for the supplier to mark this order delivered.");
            o.Status = SupplyOrderStatus.COMPLETED; o.Version++;
            return Map(o);
        }, ct);

    private async Task<SupplyOrder> OrderAsync(Guid house, Guid id, CancellationToken ct)
    {
        var o = await store.OrderAsync(id, ct) ?? throw new NotFoundException("Purchase not found.");
        if (o.HouseId != house) throw new ForbiddenException();
        return o;
    }
    public async Task ExpireAsync(Guid id,CancellationToken ct)
    {
        var probe=await store.OrderAsync(id,ct);if(probe==null)return;
        await mutations.RunAsync(probe.HouseId,async()=>{
            var o=await store.OrderAsync(id,ct);
            if(o==null||o.Status!=SupplyOrderStatus.APPROVED||o.QuoteExpiresAt>clock.GetUtcNow().UtcDateTime||(await store.PaymentsAsync(id,ct)).Count>0)return;
            if(o.StockReserved){foreach(var line in o.Lines.OrderBy(x=>x.ProductId))await store.ReleaseAsync(line.ProductId,line.Quantity,ct);o.StockReserved=false;}
            o.Status=SupplyOrderStatus.CANCELLED;o.Version++;
        },ct);
    }
    public static void CheckVersion(SupplyOrder order, int version) {
        if (order.Workflow == SupplyOrderWorkflow.SIMPLE_CONTACT) throw new ConflictException("Use Send order and Record payment for this order.");
        if (order.Version != version) throw new ConflictException("This order changed. Refresh and review the latest version."); }
    private void CheckQuote(SupplyOrder o) { if (clock.GetUtcNow().UtcDateTime >= o.QuoteExpiresAt) throw new ConflictException("This quote expired. Create a new draft to review current prices."); }
    private Task Notify(SupplyOrder order, Guid actor, Guid? recipient, string title, string message, CancellationToken ct) =>
        events.PublishAsync(new SupplyNotificationEvent(order.HouseId, order.Id, SupplyConstants.OrderTarget, actor, recipient, title, message), ct);
}
