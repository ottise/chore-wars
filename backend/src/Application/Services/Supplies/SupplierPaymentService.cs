using System.Security.Cryptography;
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
namespace ChoreWars.Application.Services.Supplies;
public sealed class SupplierPaymentService(ISupplyRepository store,IUnitOfWork uow,IHouseAccessService access,IHouseMutationCoordinator mutations,
 IPurchasePaymentGateway gateway,IEventPublisher events,TimeProvider clock):ISupplierPaymentService
{
 private static SupplierCheckoutResponse Map(SupplierPayment p)=>new(p.Id,p.Status.ToString(),p.CheckoutUrl,p.QrCode,p.ExpiresAt);
 public async Task<SupplierCheckoutResponse> CheckoutAsync(Guid house,Guid order,Guid actor,int version,CancellationToken ct)
 {
  var request=await mutations.RunAsync(house,async()=>{
   await access.EnsureActiveAsync(house,actor,ct);await access.EnsureWritableAsync(house,ct);
   var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Order not found.");
   if(o.HouseId!=house||o.PayerUserId!=actor)throw new ForbiddenException("Only the designated payer can checkout.");
   var previous=(await store.PaymentsAsync(order,ct)).FirstOrDefault();
   if(previous!=null)return previous;
   SupplyOrderService.CheckVersion(o,version);
   if(o.Status!=SupplyOrderStatus.APPROVED||!o.StockReserved||!o.Shares.All(s=>s.ApprovedAt.HasValue))throw new ConflictException("Every participant must approve before checkout.");
   if(clock.GetUtcNow().UtcDateTime>=o.QuoteExpiresAt)throw new ConflictException("This quote expired. Cancel and create a new purchase.");
   foreach(var s in o.Shares)await access.EnsureActiveAsync(house,s.UserId,ct);
   gateway.EnsureConfigured();
   var payment=new SupplierPayment{Id=Guid.NewGuid(),OrderId=o.Id,Amount=o.Total,OrderCode=RandomNumberGenerator.GetInt32(100_000_000,1_000_000_000)+(DateTimeOffset.UtcNow.ToUnixTimeSeconds()*1_000_000),
    CreatedAt=clock.GetUtcNow().UtcDateTime,ExpiresAt=clock.GetUtcNow().UtcDateTime.AddMinutes(SupplyConstants.CheckoutMinutes)};
   store.Add(payment);return payment;
  },ct);
  if(request.Status!=SupplierPaymentStatus.CREATING)return Map(request);
  // The same order code is retained through failures; a second checkout never silently creates a second charge.
  var link=await gateway.CreateAsync(new(request.OrderCode,request.Amount,"Household supplies",request.ExpiresAt,order,house),ct);
  return await mutations.RunAsync(house,async()=>{
   var p=await store.PaymentAsync(request.Id,ct)??throw new NotFoundException("Payment not found.");
   if(p.Status==SupplierPaymentStatus.CREATING){p.PaymentLinkId=link.PaymentLinkId;p.CheckoutUrl=link.CheckoutUrl;p.QrCode=link.QrCode;p.Status=SupplierPaymentStatus.PENDING;}
   return Map(p);
  },ct);
 }
 public async Task<SupplierCheckoutResponse?> RefreshAsync(Guid house,Guid order,Guid actor,CancellationToken ct)
 {
  await access.EnsureActiveAsync(house,actor,ct);var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Order not found.");if(o.HouseId!=house)throw new ForbiddenException();
  var p=(await store.PaymentsAsync(order,ct)).FirstOrDefault();if(p==null)return null;
  if(p.Status!=SupplierPaymentStatus.VERIFIED)await ReconcileAsync(p.Id,ct);
  p=await store.PaymentAsync(p.Id,ct);return p==null?null:Map(p);
 }
 public async Task WebhookAsync(JsonElement payload,CancellationToken ct)
 {
  var result=await gateway.VerifyAsync(payload,ct);await Apply(result,ct);
 }
 public async Task ReconcileAsync(Guid payment,CancellationToken ct)
 {
  var p=await store.PaymentAsync(payment,ct)??throw new NotFoundException("Payment not found.");
  if(p.Status==SupplierPaymentStatus.VERIFIED)return;
  await Apply(await gateway.QueryAsync(p.OrderCode,ct),ct);
 }
 private async Task Apply(SupplierPaymentResult r,CancellationToken ct)
 {
  var probe=await store.PaymentCodeAsync(r.OrderCode,ct)??throw new NotFoundException("Unknown supplier payment.");
  var order=await store.OrderAsync(probe.OrderId,ct)??throw new NotFoundException("Order not found.");
  await mutations.RunAsync(order.HouseId,async()=>{
   var p=await store.PaymentCodeAsync(r.OrderCode,ct)??throw new NotFoundException("Payment not found.");
   var o=await store.OrderAsync(p.OrderId,ct)??throw new NotFoundException("Order not found.");
   if(p.Status==SupplierPaymentStatus.VERIFIED)return;
   if(!string.IsNullOrEmpty(p.PaymentLinkId)&&p.PaymentLinkId!=r.PaymentLinkId)throw new ConflictException("Payment link does not match.");
   if(r.Status!="PAID"){
    if(r.Status is "CANCELLED" or "EXPIRED") {
     p.Status=SupplierPaymentStatus.EXPIRED;
     if(o.Status==SupplyOrderStatus.APPROVED&&o.StockReserved){foreach(var line in o.Lines.OrderBy(x=>x.ProductId))await store.ReleaseAsync(line.ProductId,line.Quantity,ct);o.StockReserved=false;o.Status=SupplyOrderStatus.CANCELLED;o.Version++;}
    }
    return;
   }
   if(r.Amount!=p.Amount || r.Amount!=o.Total)throw new ConflictException("The received amount needs manual reconciliation.");
   if(o.Status!=SupplyOrderStatus.APPROVED||!o.StockReserved)throw new ConflictException("Late payment needs review before fulfillment.");
   if(await store.ReceiptExistsAsync(r.Reference,ct))throw new ConflictException("This payment reference was already applied.");
   p.Status=SupplierPaymentStatus.VERIFIED;p.Reference=r.Reference;p.PaymentLinkId=r.PaymentLinkId;o.Status=SupplyOrderStatus.PAID;o.PaidAt=clock.GetUtcNow().UtcDateTime;o.Version++;
   store.Add(new PaymentWebhookReceipt{Id=Guid.NewGuid(),PaymentId=p.Id,Reference=r.Reference,ReceivedAt=o.PaidAt.Value});
   foreach(var share in o.Shares.Where(s=>s.UserId!=o.PayerUserId&&s.Amount>0))
    await uow.PaymentObligations.AddAsync(new PaymentObligation{Id=Guid.NewGuid(),HouseId=o.HouseId,SourceOrderId=o.Id,DebtorUserId=share.UserId,CreditorUserId=o.PayerUserId,Amount=share.Amount,Reason=PaymentObligationReason.HOUSEHOLD_PURCHASE,Status=PaymentObligationStatus.PENDING,CreatedAt=o.PaidAt.Value},ct);
   await events.PublishAsync(new SupplyNotificationEvent(o.HouseId,o.Id,SupplyConstants.OrderTarget,o.PayerUserId,null,"Supplier payment received","Your purchase is paid. Direct reimbursements are available in Household Debts."),ct);
  },ct);
 }
}
