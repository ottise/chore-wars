using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using FluentValidation;
namespace ChoreWars.Application.Services.Supplies;
public sealed class SupplyDisputeService(ISupplyRepository store,IHouseAccessService access,IHouseMutationCoordinator mutations,IEventPublisher events,TimeProvider clock,
 IValidator<CreateSupplyDisputeRequest> validator,IValidator<ProposeSupplyResolutionRequest> proposalValidator):ISupplyDisputeService
{
 private static SupplyDisputeResponse Map(SupplyDispute d)=>new(d.Id,d.CreatorUserId,d.ProductId,d.Reason,d.Resolution,d.CreatedAt,d.ProposedAt,d.AcceptedAt);
 public async Task<List<SupplyDisputeResponse>> ListAsync(Guid order,Guid actor,CancellationToken ct){var o=await Order(order,ct);var s=await store.SupplierAsync(o.SupplierId,ct);if(s?.OperatorUserId!=actor)await access.EnsureActiveAsync(o.HouseId,actor,ct);return(await store.DisputesAsync(order,ct)).Select(Map).ToList();}
 public async Task<SupplyDisputeResponse>CreateAsync(Guid order,Guid actor,CreateSupplyDisputeRequest r,CancellationToken ct){
  await validator.ValidateAndThrowAsync(r,ct);var probe=await Order(order,ct);
  return await mutations.RunAsync(probe.HouseId,async()=>{var o=await Order(order,ct);await access.EnsureActiveAsync(o.HouseId,actor,ct);
   if(o.PaidAt==null||!o.Shares.Any(x=>x.UserId==actor))throw new ForbiddenException("Only a participant in a paid purchase can report a problem.");
   if(r.ProductId.HasValue&&!o.Lines.Any(x=>x.ProductId==r.ProductId))throw new DomainException("This product is not part of the purchase.");
   var old=(await store.DisputesAsync(order,ct)).SingleOrDefault(x=>x.CreatorUserId==actor&&x.ClientRequestId==r.ClientRequestId);
   if(old!=null){if(old.Reason!=r.Reason.Trim()||old.ProductId!=r.ProductId)throw new ConflictException("Request ID already used.");return Map(old);}
   var item=new SupplyDispute{Id=Guid.NewGuid(),OrderId=order,CreatorUserId=actor,ClientRequestId=r.ClientRequestId,ProductId=r.ProductId,Reason=r.Reason.Trim(),CreatedAt=clock.GetUtcNow().UtcDateTime};store.Add(item);
   await Notify(o,actor,"Purchase problem reported","A participant reported a problem. Review the purchase and contact the supplier.",ct);return Map(item);
  },ct);
 }
 public async Task<SupplyDisputeResponse>ProposeAsync(Guid order,Guid dispute,Guid actor,ProposeSupplyResolutionRequest r,CancellationToken ct){
  await proposalValidator.ValidateAndThrowAsync(r,ct);var probe=await Order(order,ct);
  return await mutations.RunAsync(probe.HouseId,async()=>{var o=await Order(order,ct);var s=await store.SupplierAsync(o.SupplierId,ct);if(s?.OperatorUserId!=actor)throw new ForbiddenException();
   var d=(await store.DisputesAsync(order,ct)).SingleOrDefault(x=>x.Id==dispute)??throw new NotFoundException("Problem report not found.");if(d.AcceptedAt.HasValue)throw new ConflictException("This problem is already resolved.");
   d.Resolution=r.Resolution.Trim();d.ProposedAt=clock.GetUtcNow().UtcDateTime;
   await Notify(o,actor,"Supplier proposed a resolution","Review the supplier response. Refunds must still be acknowledged separately when money is received.",ct);return Map(d);
  },ct);
 }
 public async Task<SupplyDisputeResponse>AcceptAsync(Guid order,Guid dispute,Guid actor,CancellationToken ct){var probe=await Order(order,ct);return await mutations.RunAsync(probe.HouseId,async()=>{
  var o=await Order(order,ct);var d=(await store.DisputesAsync(order,ct)).SingleOrDefault(x=>x.Id==dispute)??throw new NotFoundException("Problem report not found.");
  if(d.CreatorUserId!=actor)throw new ForbiddenException("Only the reporting participant can accept the resolution.");if(d.AcceptedAt.HasValue)return Map(d);if(d.ProposedAt==null)throw new ConflictException("Wait for a supplier response first.");
  d.AcceptedAt=clock.GetUtcNow().UtcDateTime;await Notify(o,actor,"Purchase problem resolved","The reporting participant accepted the supplier resolution. Financial transfers retain their own confirmation history.",ct);return Map(d);
 },ct);}
 private async Task<SupplyOrder> Order(Guid id,CancellationToken ct)=>await store.OrderAsync(id,ct)??throw new NotFoundException("Purchase not found.");
 private Task Notify(SupplyOrder o,Guid actor,string title,string message,CancellationToken ct)=>events.PublishAsync(new SupplyNotificationEvent(o.HouseId,o.Id,SupplyConstants.OrderTarget,actor,null,title,message),ct);
}
