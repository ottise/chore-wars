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
public sealed class SupplyReminderService(ISupplyRepository store,IUnitOfWork uow,IHouseAccessService access,IHouseMutationCoordinator mutations,
 IEventPublisher events,TimeProvider clock,IValidator<CreateSupplyScheduleRequest> validator):ISupplyReminderService
{
 private static readonly TimeZoneInfo Zone=TimeZoneInfo.FindSystemTimeZoneById(SupplyConstants.TimeZone);
 private static SupplyScheduleResponse Map(SupplySchedule s)=>new(s.Id,s.Items,s.DayOfMonth,s.Hour,s.Minute,s.TimeZone,s.Enabled,s.NextDueAt,s.SnoozedUntil,s.Version);
 public static DateTime Next(int day,int hour,int minute,DateTime afterUtc)
 {
  var local=TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(afterUtc,DateTimeKind.Utc),Zone);
  for(var i=0;i<=1;i++){
   var month=new DateTime(local.Year,local.Month,1).AddMonths(i);
   var candidate=new DateTime(month.Year,month.Month,Math.Min(day,DateTime.DaysInMonth(month.Year,month.Month)),hour,minute,0,DateTimeKind.Unspecified);
   var utc=TimeZoneInfo.ConvertTimeToUtc(candidate,Zone);if(utc>afterUtc)return utc;
  }
  throw new DomainException("Cannot calculate the next reminder date.");
 }
 public async Task<List<SupplyScheduleResponse>> ListAsync(Guid house,Guid actor,CancellationToken ct){await access.EnsureActiveAsync(house,actor,ct);return(await store.SchedulesAsync(house,ct)).Select(Map).ToList();}
 private async Task Owner(Guid house,Guid actor,CancellationToken ct){await access.EnsureActiveAsync(house,actor,ct);await access.EnsureWritableAsync(house,ct);var m=await uow.HouseMembers.GetByHouseAndUserIdAsync(house,actor,ct);if(m?.Role!=HouseRole.OWNER)throw new ForbiddenException("The house owner must approve a group reminder schedule.");}
 public async Task<SupplyScheduleResponse> CreateAsync(Guid house,Guid actor,CreateSupplyScheduleRequest r,CancellationToken ct)
 {
  await validator.ValidateAndThrowAsync(r,ct);
  return await mutations.RunAsync(house,async()=>{
   await Owner(house,actor,ct);var old=(await store.SchedulesAsync(house,ct)).SingleOrDefault(x=>x.ClientRequestId==r.ClientRequestId);
   if(old!=null){if(old.Items!=r.Items.Trim()||old.DayOfMonth!=r.DayOfMonth||old.Hour!=r.Hour||old.Minute!=r.Minute)throw new ConflictException("Request ID already used for a different schedule.");return Map(old);}
   var s=new SupplySchedule{Id=Guid.NewGuid(),HouseId=house,CreatedByUserId=actor,ClientRequestId=r.ClientRequestId,Items=r.Items.Trim(),DayOfMonth=r.DayOfMonth,Hour=r.Hour,Minute=r.Minute,QuietFromHour=r.QuietFromHour,QuietToHour=r.QuietToHour,NextDueAt=Next(r.DayOfMonth,r.Hour,r.Minute,clock.GetUtcNow().UtcDateTime)};
   store.Add(s);return Map(s);
  },ct);
 }
 public Task<SupplyScheduleResponse> UpdateAsync(Guid house,Guid id,Guid actor,UpdateSupplyScheduleRequest r,CancellationToken ct)=>mutations.RunAsync(house,async()=>{
  await Owner(house,actor,ct);var s=await store.ScheduleAsync(id,ct)??throw new NotFoundException("Schedule not found.");if(s.HouseId!=house)throw new ForbiddenException();
  if(s.Version!=r.ExpectedVersion)throw new ConflictException("Schedule changed. Refresh first.");
  if(r.SnoozedUntil.HasValue&&(r.SnoozedUntil<=clock.GetUtcNow().UtcDateTime||r.SnoozedUntil>clock.GetUtcNow().UtcDateTime.AddDays(31)))throw new DomainException("Snooze must be within the next month.");
  s.Enabled=r.Enabled;s.SnoozedUntil=r.SnoozedUntil;s.Version++;return Map(s);
 },ct);
 public async Task ProcessAsync(Guid schedule,CancellationToken ct)
 {
  var probe=await store.ScheduleAsync(schedule,ct);if(probe==null)return;
  await mutations.RunAsync(probe.HouseId,async()=>{
   var s=await store.ScheduleAsync(schedule,ct);var now=clock.GetUtcNow().UtcDateTime;
   if(s==null||!s.Enabled||s.NextDueAt>now||s.SnoozedUntil>now)return;
   var house=await uow.Houses.GetByIdAsync(s.HouseId,ct);if(house==null||house.IsArchived){s.Enabled=false;s.Version++;return;}
   var local=TimeZoneInfo.ConvertTimeFromUtc(now,Zone);
   var quiet=s.QuietFromHour!=s.QuietToHour&&(s.QuietFromHour<s.QuietToHour?local.Hour>=s.QuietFromHour&&local.Hour<s.QuietToHour:local.Hour>=s.QuietFromHour||local.Hour<s.QuietToHour);
   if(quiet)return;
   var occurrence=s.NextDueAt;
   if(!await store.ReminderExistsAsync(s.Id,occurrence,ct)){
    var pending=(await store.OrdersAsync(s.HouseId,null,ct)).FirstOrDefault(x=>x.Status is SupplyOrderStatus.AWAITING_APPROVAL or SupplyOrderStatus.APPROVED or SupplyOrderStatus.PAID or SupplyOrderStatus.FULFILLING);
    store.Add(new SupplyReminderDelivery{Id=Guid.NewGuid(),ScheduleId=s.Id,OccurrenceAt=occurrence,CreatedAt=now});
    await events.PublishAsync(new SupplyNotificationEvent(s.HouseId,pending?.Id??s.Id,pending==null?SupplyConstants.ScheduleTarget:SupplyConstants.OrderTarget,s.CreatedByUserId,null,
     "Time to check household supplies",pending==null?$"Scheduled check: {s.Items}. Check what is available before ordering. You can ask AI or order supplies yourself.":"You already have an open purchase. Check it before ordering more supplies."),ct);
   }
   s.NextDueAt=Next(s.DayOfMonth,s.Hour,s.Minute,now);s.SnoozedUntil=null;s.Version++;
  },ct);
 }
}
