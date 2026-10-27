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
public sealed class InternalRepaymentService(ISupplyRepository store,IUnitOfWork uow,IHouseAccessService access,
 IHouseMutationCoordinator mutations,IEventPublisher events,TimeProvider clock,IValidator<ReportRepaymentRequest> validator,
 IValidator<ConfirmRepaymentRequest> responseValidator) : IInternalRepaymentService
{
 public async Task<PurchaseDebtSummaryResponse> SummaryAsync(Guid house,Guid actor,CancellationToken ct)
 {
  await access.EnsureActiveAsync(house,actor,ct);
  var all=(await uow.PaymentObligations.GetByHouseIdAsync(house,ct)).Where(x=>x.Reason==PaymentObligationReason.HOUSEHOLD_PURCHASE&&(x.DebtorUserId==actor||x.CreditorUserId==actor)).ToList();
  var rows=new List<PurchaseDebtResponse>();foreach(var d in all)rows.Add(await Map(d,ct));
  var orders=(await store.OrdersAsync(house,null,ct)).Where(x=>x.PaidAt!=null).ToList();
  return new(orders.Where(x=>x.PayerUserId==actor).Sum(x=>x.Total-x.RefundedAmount),orders.Sum(x=>x.Shares.Where(s=>s.UserId==actor).Sum(s=>s.Amount)-SupplyRefundService.Allocate(x,x.RefundedAmount).GetValueOrDefault(actor)),
   rows.Where(x=>x.DebtorUserId==actor).Sum(x=>x.ConfirmedAmount),rows.Where(x=>x.CreditorUserId==actor).Sum(x=>x.ConfirmedAmount),
   rows.Where(x=>x.DebtorUserId==actor).Sum(x=>x.RemainingAmount),rows.Where(x=>x.CreditorUserId==actor).Sum(x=>x.RemainingAmount),rows);
 }
 public async Task<PurchaseDebtResponse> ReadAsync(Guid id,Guid actor,CancellationToken ct)=>await Map(await Debt(id,actor,ct),ct);
 public async Task<PurchaseDebtResponse> ReportAsync(Guid id,Guid actor,ReportRepaymentRequest r,CancellationToken ct)
 {
  await validator.ValidateAndThrowAsync(r,ct);
  var probe=await Debt(id,actor,ct);
  return await mutations.RunAsync(probe.HouseId,async()=> {
   var d=await Debt(id,actor,ct);if(d.DebtorUserId!=actor)throw new ForbiddenException("Only the debtor can report a transfer.");
   var reports=await store.RepaymentsAsync(id,ct);var old=reports.SingleOrDefault(x=>x.ClientRequestId==r.ClientRequestId);
   if(old!=null){if(old.Amount!=r.Amount||old.Reference!=r.Reference.Trim())throw new ConflictException("Request ID already used.");return await Map(d,ct);}
   var snapshot=await Map(d,ct);
   if(d.Status!=PaymentObligationStatus.PENDING||r.Amount>snapshot.RemainingAmount-reports.Where(x=>x.Status==InternalRepaymentStatus.REPORTED).Sum(x=>x.Amount))
    throw new ConflictException("This exceeds the amount not already paid or awaiting confirmation.");
   store.Add(new InternalRepayment{Id=Guid.NewGuid(),ObligationId=id,ClientRequestId=r.ClientRequestId,Amount=r.Amount,Reference=r.Reference.Trim(),ReportedAt=clock.GetUtcNow().UtcDateTime});
   await events.PublishAsync(new SupplyNotificationEvent(d.HouseId,d.Id,SupplyConstants.RepaymentTarget,actor,d.CreditorUserId,"Transfer reported","Confirm the money you actually received to update this purchase debt."),ct);
   return await Map(d,ct);
  },ct);
 }
 public async Task<PurchaseDebtResponse> RespondAsync(Guid id,Guid repayment,Guid actor,ConfirmRepaymentRequest r,CancellationToken ct)
 {
  await responseValidator.ValidateAndThrowAsync(r,ct);
  var probe=await Debt(id,actor,ct);
  return await mutations.RunAsync(probe.HouseId,async()=> {
   var d=await Debt(id,actor,ct);if(d.CreditorUserId!=actor)throw new ForbiddenException("Only the creditor can confirm receipt.");
   var reports=await store.RepaymentsAsync(id,ct);var item=reports.SingleOrDefault(x=>x.Id==repayment)??throw new NotFoundException("Transfer report not found.");
   if(item.Status!=InternalRepaymentStatus.REPORTED){if((item.Status==InternalRepaymentStatus.CONFIRMED)==r.Confirm)return await Map(d,ct);throw new ConflictException("This transfer already has a final decision.");}
   var snapshot=await Map(d,ct);
   if(r.Confirm && (d.Status!=PaymentObligationStatus.PENDING||item.Amount>snapshot.RemainingAmount))throw new ConflictException("The remaining amount changed. Review the purchase before confirming.");
   item.Status=r.Confirm?InternalRepaymentStatus.CONFIRMED:InternalRepaymentStatus.REJECTED;item.RespondedAt=clock.GetUtcNow().UtcDateTime;item.ResponseReason=r.Reason?.Trim();
   if(r.Confirm && item.Amount==snapshot.RemainingAmount){d.Status=PaymentObligationStatus.PAID;d.PaidAt=item.RespondedAt;d.ConfirmedByUserId=actor;}
   await events.PublishAsync(new SupplyNotificationEvent(d.HouseId,d.Id,SupplyConstants.RepaymentTarget,actor,d.DebtorUserId,"Transfer reviewed",r.Confirm?"The creditor confirmed receipt.":"The creditor rejected this report. Check the transfer details."),ct);
   return await Map(d,ct);
  },ct);
 }
 public async Task<RepaymentInstructionsResponse> InstructionsAsync(Guid id,Guid actor,CancellationToken ct)
 {
  var d=await Debt(id,actor,ct);if(d.DebtorUserId!=actor)throw new ForbiddenException();
  var row=await Map(d,ct);var b=await store.BankAsync(d.CreditorUserId,ct);
  return new(d.CreditorUserId,row.CreditorName,row.RemainingAmount,$"CW-{d.Id.ToString("N")[..12]}",b?.Active==true?UserBankAccountService.Map(b):null);
 }
 private async Task<PaymentObligation> Debt(Guid id,Guid actor,CancellationToken ct)
 {
  var d=await uow.PaymentObligations.GetByIdAsync(id,ct)??throw new NotFoundException("Purchase debt not found.");
  if(d.Reason!=PaymentObligationReason.HOUSEHOLD_PURCHASE || !d.SourceOrderId.HasValue)throw new DomainException("Use the original payment flow for this obligation.");
  if(d.DebtorUserId!=actor&&d.CreditorUserId!=actor)throw new ForbiddenException();return d;
 }
 private async Task<PurchaseDebtResponse> Map(PaymentObligation d,CancellationToken ct)
 {
  var reports=await store.RepaymentsAsync(d.Id,ct);var adjustments=(await store.AdjustmentsAsync(d.Id,ct)).Sum(x=>x.Amount);
  var paid=reports.Where(x=>x.Status==InternalRepaymentStatus.CONFIRMED).Sum(x=>x.Amount);
  var debtor=await uow.Users.GetByIdAsync(d.DebtorUserId,ct);var creditor=await uow.Users.GetByIdAsync(d.CreditorUserId,ct);
  return new(d.Id,d.SourceOrderId!.Value,d.DebtorUserId,debtor?.DisplayName??"Former member",d.CreditorUserId,creditor?.DisplayName??"Former member",d.Amount,adjustments,paid,Math.Max(0,d.Amount+adjustments-paid),d.Status.ToString(),
   reports.Select(x=>new InternalRepaymentResponse(x.Id,x.Amount,x.Reference,x.Status.ToString(),x.ReportedAt,x.RespondedAt,x.ResponseReason)).ToList());
 }
}
