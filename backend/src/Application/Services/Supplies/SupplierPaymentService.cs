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
  var previous=await mutations.RunAsync(house,async()=>{
   await access.EnsureActiveAsync(house,actor,ct);await access.EnsureWritableAsync(house,ct);
   var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Order not found.");
   if(o.HouseId!=house)throw new NotFoundException("Order not found.");
   var simpleOrder=o.Workflow is SupplyOrderWorkflow.SIMPLE_SMS or SupplyOrderWorkflow.SIMPLE_CONTACT;
   if(!simpleOrder&&o.PayerUserId!=actor)throw new ForbiddenException("Only the designated payer can checkout.");
   return (await store.PaymentsAsync(order,ct)).FirstOrDefault(p=>p.Status is SupplierPaymentStatus.CREATING or SupplierPaymentStatus.PENDING or SupplierPaymentStatus.VERIFIED);
  },ct);

  if(previous?.Status==SupplierPaymentStatus.VERIFIED)return Map(previous);
  if(previous?.Status==SupplierPaymentStatus.PENDING)
  {
   // Reconcile first. When the short PayOS window elapsed, close the old link
   // before issuing a replacement so two links cannot collect the same order.
   var remote=await gateway.QueryAsync(previous.OrderCode,ct);
   await Apply(remote,ct);
   previous=await store.PaymentAsync(previous.Id,ct)??throw new NotFoundException("Payment not found.");
   var currentOrder=await store.OrderAsync(order,ct)??throw new NotFoundException("Order not found.");
   if(previous.Status==SupplierPaymentStatus.VERIFIED||currentOrder.Status==SupplyOrderStatus.PAID)return Map(previous);
   if(remote.Status is "CANCELLED" or "EXPIRED")previous=null;
   else if(remote.Status=="PENDING"&&previous.ExpiresAt<=clock.GetUtcNow().UtcDateTime)
   {
    SupplierPaymentResult cancelled;
    try
    {
     cancelled=await gateway.CancelAsync(previous.OrderCode,previous.PaymentLinkId,"Checkout link expired; replacing it.",ct);
    }
    catch(ConflictException)
    {
     // The transfer may settle between the query and cancellation.
     var final=await gateway.QueryAsync(previous.OrderCode,ct);
     await Apply(final,ct);
     previous=await store.PaymentAsync(previous.Id,ct)??throw new NotFoundException("Payment not found.");
     if(previous.Status==SupplierPaymentStatus.VERIFIED)return Map(previous);
     throw new ConflictException("The old PayOS payment is still processing. Check its status before retrying.");
    }
    await Apply(cancelled,ct);
    previous=await store.PaymentAsync(previous.Id,ct)??throw new NotFoundException("Payment not found.");
    if(previous.Status==SupplierPaymentStatus.VERIFIED)return Map(previous);
    if(previous.Status!=SupplierPaymentStatus.EXPIRED)
     throw new ConflictException("PayOS has not closed the expired link yet. Check payment status and retry shortly.");
    previous=null;
   }
   else if(remote.Status!="PENDING")
    throw new ConflictException("The payment is processing. Check its status before creating another checkout.");
   else return Map(previous);
  }

  var request=await mutations.RunAsync(house,async()=>{
   await access.EnsureActiveAsync(house,actor,ct);await access.EnsureWritableAsync(house,ct);
   var o=await store.OrderAsync(order,ct)??throw new NotFoundException("Order not found.");
   if(o.HouseId!=house)throw new NotFoundException("Order not found.");
   if(o.PayerUserId!=actor)throw new ForbiddenException("Only the designated payer can checkout.");
   var active=(await store.PaymentsAsync(order,ct)).FirstOrDefault(p=>p.Status is SupplierPaymentStatus.CREATING or SupplierPaymentStatus.PENDING or SupplierPaymentStatus.VERIFIED);
   if(active!=null)return active;
   if(o.Status==SupplyOrderStatus.PAID)throw new ConflictException("This order has already been paid.");
   var simple=simpleOrder;
   if(simple){if(o.Version!=version)throw new ConflictException("This order changed. Refresh and try again.");if(o.Status!=SupplyOrderStatus.DRAFT)throw new ConflictException("Only an unpaid order can start PayOS checkout.");}
   else {SupplyOrderService.CheckVersion(o,version);if(o.Status!=SupplyOrderStatus.APPROVED||!o.StockReserved||!o.Shares.All(s=>s.ApprovedAt.HasValue))throw new ConflictException("Every participant must approve before checkout.");}
   // A saved simple order retains its agreed amount after the catalog quote expires.
   if(!simple&&clock.GetUtcNow().UtcDateTime>=o.QuoteExpiresAt)throw new ConflictException("This quote expired. Cancel and create a new purchase.");
   if(o.Shares.Count==0)throw new ConflictException("Choose household cost shares before checkout.");
   if(o.Shares.Sum(s=>s.Amount)!=o.Total)throw new ConflictException("Household shares do not match the order total.");
   foreach(var s in o.Shares)await access.EnsureActiveAsync(house,s.UserId,ct);
   if(simple&&o.PayerUserId!=actor){o.PayerUserId=actor;o.Version++;}
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
   var simple=o.Workflow is SupplyOrderWorkflow.SIMPLE_SMS or SupplyOrderWorkflow.SIMPLE_CONTACT;
   if(simple ? o.Status!=SupplyOrderStatus.DRAFT : o.Status!=SupplyOrderStatus.APPROVED||!o.StockReserved)
    throw new ConflictException("Late payment needs review before fulfillment.");
   if(await store.ReceiptExistsAsync(r.Reference,ct))throw new ConflictException("This payment reference was already applied.");
   p.Status=SupplierPaymentStatus.VERIFIED;p.Reference=r.Reference;p.PaymentLinkId=r.PaymentLinkId;o.Status=SupplyOrderStatus.PAID;o.PaidAt=clock.GetUtcNow().UtcDateTime;o.Version++;
   o.RecordedPaidAmount=r.Amount;o.PaymentRecordedByUserId=o.PayerUserId;o.PaymentRecordedAt=o.PaidAt;
   o.PaymentConfirmationSource="PAYOS_VERIFIED";o.PaymentReference=r.Reference;
   store.Add(new PaymentWebhookReceipt{Id=Guid.NewGuid(),PaymentId=p.Id,Reference=r.Reference,ReceivedAt=o.PaidAt.Value});
   foreach(var share in o.Shares.Where(s=>s.UserId!=o.PayerUserId&&s.Amount>0))
    await uow.PaymentObligations.AddAsync(new PaymentObligation{Id=Guid.NewGuid(),HouseId=o.HouseId,SourceOrderId=o.Id,DebtorUserId=share.UserId,CreditorUserId=o.PayerUserId,Amount=share.Amount,Reason=PaymentObligationReason.HOUSEHOLD_PURCHASE,Status=PaymentObligationStatus.PENDING,CreatedAt=o.PaidAt.Value},ct);
   await events.PublishAsync(new SupplyNotificationEvent(o.HouseId,o.Id,SupplyConstants.OrderTarget,o.PayerUserId,null,"Supplier payment received","Your purchase is paid. Direct reimbursements are available in Household Debts."),ct);
  },ct);
 }
}
