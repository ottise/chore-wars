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
public sealed class SupplyRefundService(ISupplyRepository store,IUnitOfWork uow,IHouseAccessService access,IHouseMutationCoordinator mutations,
 IEventPublisher events,TimeProvider clock,IValidator<SupplyRefundRequest> validator):ISupplyRefundService
{
 private static SupplierRefundResponse Map(SupplierRefund r)=>new(r.Id,r.Amount,r.Reference,r.Reason,r.ReportedAt,r.ConfirmedAt,r.RejectedAt);
 public async Task<List<SupplierRefundResponse>> ListAsync(Guid order,Guid actor,CancellationToken ct){var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");
  var s=await store.SupplierAsync(o.SupplierId,ct);if(s?.OperatorUserId!=actor)await access.EnsureActiveAsync(o.HouseId,actor,ct);
  return(await store.RefundsAsync(order,ct)).Select(Map).ToList();}
 public async Task<SupplierRefundResponse> ReportAsync(Guid order,Guid actor,SupplyRefundRequest r,CancellationToken ct){
  await validator.ValidateAndThrowAsync(r,ct);var probe=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");
  return await mutations.RunAsync(probe.HouseId,async()=>{
   var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");var supplier=await store.SupplierAsync(o.SupplierId,ct);
   if(supplier?.OperatorUserId!=actor)throw new ForbiddenException();if(o.PaidAt==null)throw new ConflictException("This order was not paid.");
   var refunds=await store.RefundsAsync(order,ct);var old=refunds.SingleOrDefault(x=>x.ClientRequestId==r.ClientRequestId);
   if(old!=null){if(old.Amount!=r.Amount||old.Reference!=r.Reference.Trim()||old.Reason!=r.Reason.Trim())throw new ConflictException("Request ID already used.");return Map(old);}
   if(refunds.Where(x=>x.RejectedAt==null).Sum(x=>x.Amount)+r.Amount>o.Total)throw new ConflictException("Refund reports exceed the order total.");
   var item=new SupplierRefund{Id=Guid.NewGuid(),OrderId=order,ClientRequestId=r.ClientRequestId,Amount=r.Amount,Reference=r.Reference.Trim(),Reason=r.Reason.Trim(),ReportedAt=clock.GetUtcNow().UtcDateTime};store.Add(item);
   await events.PublishAsync(new SupplyNotificationEvent(o.HouseId,o.Id,SupplyConstants.OrderTarget,actor,o.PayerUserId,"Supplier refund reported","Confirm only the refund you actually received. Internal debts remain unchanged until then."),ct);return Map(item);
  },ct);
 }
 public async Task<SupplierRefundResponse> ConfirmAsync(Guid order,Guid refund,Guid actor,CancellationToken ct){
  var probe=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");
  return await mutations.RunAsync(probe.HouseId,async()=>{
   var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");if(o.PayerUserId!=actor)throw new ForbiddenException("Only the payer can acknowledge money returned by the supplier.");
   var r=(await store.RefundsAsync(order,ct)).SingleOrDefault(x=>x.Id==refund)??throw new NotFoundException("Refund report not found.");if(r.ConfirmedAt.HasValue)return Map(r);
   if(r.RejectedAt.HasValue)throw new ConflictException("This refund report was rejected. Ask the supplier to report the actual refund.");
   var previous=Allocate(o,o.RefundedAmount);var next=Allocate(o,o.RefundedAmount+r.Amount);
   var debts=(await uow.PaymentObligations.GetByHouseIdAsync(o.HouseId,ct)).Where(x=>x.SourceOrderId==o.Id).ToList();
   foreach(var share in o.Shares.Where(x=>x.UserId!=actor&&x.Amount>0)){
    var original=debts.Single(x=>!x.IsPurchaseRefund&&x.DebtorUserId==share.UserId&&x.CreditorUserId==actor);
    var reduction=next[share.UserId]-previous[share.UserId];
    if(reduction>0)store.Add(new ObligationAdjustment{Id=Guid.NewGuid(),ObligationId=original.Id,SourceOrderId=o.Id,Amount=-reduction,ActorUserId=actor,Reason=r.Reason,CreatedAt=clock.GetUtcNow().UtcDateTime});
    var repayments=await store.RepaymentsAsync(original.Id,ct);var received=repayments.Where(x=>x.Status==InternalRepaymentStatus.CONFIRMED).Sum(x=>x.Amount);
    foreach(var pending in repayments.Where(x=>x.Status==InternalRepaymentStatus.REPORTED)){pending.Status=InternalRepaymentStatus.REJECTED;pending.RespondedAt=clock.GetUtcNow().UtcDateTime;pending.ResponseReason="Supplier refund changed this debt. Review and report any actual transfer again.";}
    var due=share.Amount-next[share.UserId];
    if(received>=due){original.Status=PaymentObligationStatus.PAID;original.PaidAt=clock.GetUtcNow().UtcDateTime;original.ConfirmedByUserId=actor;}
    var overpaid=Math.Max(0,received-due);var reverse=debts.SingleOrDefault(x=>x.IsPurchaseRefund&&x.DebtorUserId==actor&&x.CreditorUserId==share.UserId);
    if(overpaid>0 && reverse==null){reverse=new PaymentObligation{Id=Guid.NewGuid(),HouseId=o.HouseId,SourceOrderId=o.Id,IsPurchaseRefund=true,DebtorUserId=actor,CreditorUserId=share.UserId,Amount=overpaid,Reason=PaymentObligationReason.HOUSEHOLD_PURCHASE,Status=PaymentObligationStatus.PENDING,CreatedAt=clock.GetUtcNow().UtcDateTime};await uow.PaymentObligations.AddAsync(reverse,ct);}
    else if(reverse!=null){var target=reverse.Amount+(await store.AdjustmentsAsync(reverse.Id,ct)).Sum(x=>x.Amount);var delta=overpaid-target;
     if(delta>0){store.Add(new ObligationAdjustment{Id=Guid.NewGuid(),ObligationId=reverse.Id,SourceOrderId=o.Id,Amount=delta,ActorUserId=actor,Reason=r.Reason,CreatedAt=clock.GetUtcNow().UtcDateTime});reverse.Status=PaymentObligationStatus.PENDING;reverse.PaidAt=null;}}
   }
   r.ConfirmedAt=clock.GetUtcNow().UtcDateTime;o.RefundedAmount+=r.Amount;o.Version++;if(o.RefundedAmount==o.Total)o.Status=SupplyOrderStatus.REFUNDED;
   await events.PublishAsync(new SupplyNotificationEvent(o.HouseId,o.Id,SupplyConstants.OrderTarget,actor,null,"Refund acknowledged","The payer acknowledged the supplier refund. Review the itemized adjustments and any money to return to members."),ct);
   return Map(r);
  },ct);
 }
 public static Dictionary<Guid,decimal> Allocate(SupplyOrder o,decimal amount){
  if(amount<0||amount>o.Total)throw new DomainException("Invalid refund total.");
  var raw=o.Shares.ToDictionary(s=>s.UserId,s=>amount*s.Amount/o.Total);var result=raw.ToDictionary(x=>x.Key,x=>decimal.Floor(x.Value));
  var remainder=(int)(amount-result.Values.Sum());foreach(var id in raw.OrderByDescending(x=>x.Value-decimal.Floor(x.Value)).ThenBy(x=>x.Key).Take(remainder).Select(x=>x.Key))result[id]++;
  return result;
 }
 public async Task<SupplierRefundResponse> RejectAsync(Guid order,Guid refund,Guid actor,CancellationToken ct){
  var probe=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");
  return await mutations.RunAsync(probe.HouseId,async()=>{
   var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Purchase not found.");if(o.PayerUserId!=actor)throw new ForbiddenException();
   var r=(await store.RefundsAsync(order,ct)).SingleOrDefault(x=>x.Id==refund)??throw new NotFoundException("Refund report not found.");
   if(r.ConfirmedAt.HasValue)throw new ConflictException("A confirmed refund cannot be rejected.");r.RejectedAt??=clock.GetUtcNow().UtcDateTime;return Map(r);
  },ct);
 }
}
