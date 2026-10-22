using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services.AI;

public sealed class AIContextBuilder(IUnitOfWork uow, IAIStateRepository ai, TimeProvider clock) : IAIContextBuilder
{
    public async Task<JsonElement> BuildAsync(Guid houseId, Guid seasonId, CancellationToken ct)
    {
        var season=await uow.Seasons.GetByIdAsync(seasonId,ct) ?? throw new NotFoundException("Season not found.");
        if (season.HouseId!=houseId) throw new NotFoundException("Season not in household.");
        var members=(await uow.HouseMembers.GetByHouseIdAsync(houseId,ct)).Where(x=>x.Status==HouseMemberStatus.ACTIVE).OrderBy(x=>x.UserId).ToList();
        var av=(await uow.MemberAvailabilities.GetBySeasonIdAsync(seasonId,ct)).ToList();
        var exceptions=await ai.AvailabilityExceptionsAsync(seasonId,ct);
        var seasonOccurrences=(await uow.ChoreOccurrences.GetBySeasonIdAsync(seasonId,ct)).Where(o=>o.Chore.Type==ChoreType.NORMAL).OrderBy(o=>o.Id).ToList();
        var allowedTemplates=seasonOccurrences.Select(o=>o.ChoreId).ToHashSet();
        var memberData=new List<object>();
        foreach (var member in members)
        {
            var limits=await uow.MemberConstraints.GetByUserAndHouseIdAsync(member.UserId,houseId,ct);
            var preferences=(await uow.MemberPreferences.GetByUserIdAsync(member.UserId,ct)).Where(p=>allowedTemplates.Contains(p.ChoreId) && p.Type is PreferenceType.PREFERRED or PreferenceType.DISLIKED).OrderBy(p=>p.ChoreId).ToDictionary(p=>p.ChoreId.ToString(),p=>p.Type.ToString());
            memberData.Add(new { id=member.UserId,name=member.User?.DisplayName ?? "",max_chores_per_week=limits?.MaxChoresPerWeek ?? AIAllocationConstants.DefaultMaxChoresPerWeek,
                max_minutes_per_day=limits?.MaxEffortMinutesPerDay ?? AIAllocationConstants.DefaultMaxEffortMinutesPerDay,
                availability=av.Where(a=>a.UserId==member.UserId).OrderBy(a=>a.DayOfWeek).Select(a=>new{day=(int)a.DayOfWeek,available=a.IsAvailable,slots=a.Slots.OrderBy(s=>s.StartMinute).Select(s=>new{start=s.StartMinute,end=s.EndMinute})}),
                date_exceptions=exceptions.Where(e=>e.UserId==member.UserId).OrderBy(e=>e.LocalDate).ToDictionary(e=>e.LocalDate.ToString("yyyy-MM-dd"),e=>JsonSerializer.Deserialize<JsonElement>(e.SlotsJson)),preferences });
        }
        var tasks=new List<object>();
        var payments=(await uow.PaymentObligations.GetByHouseIdAsync(houseId,ct)).ToList();
        foreach (var occurrence in seasonOccurrences)
        {
            var bounty=await uow.ChoreBounties.GetByOccurrenceIdAsync(occurrence.Id,ct);
            var locked=season.Status!=SeasonStatus.DRAFT && (occurrence.Status!=ChoreOccurrenceStatus.ASSIGNED || occurrence.DueDate<=clock.GetUtcNow().UtcDateTime || occurrence.PenaltyCount>0 || occurrence.IsForcedReassigned || bounty!=null || payments.Any(p=>p.OccurrenceId==occurrence.Id));
            tasks.Add(new { id=occurrence.Id,template_id=occurrence.ChoreId,history_template_id=occurrence.Chore.SourceTemplateId ?? occurrence.ChoreId,name=occurrence.Chore.Name,due_at=DateTime.SpecifyKind(occurrence.DueDate,DateTimeKind.Utc),
                minutes=ChoreWars.Application.Services.AllocationEligibilityService.Minutes(occurrence),karma=occurrence.SnapshotKarma,status=occurrence.Status.ToString(),assigned_to=occurrence.AssignedUserId,start_at=occurrence.PlannedStartAt,locked });
        }
        var house=await uow.Houses.GetByIdAsync(houseId,ct) ?? throw new NotFoundException("House not found.");
        return JsonSerializer.SerializeToElement(new{house_id=houseId,owner_id=members.Single(m=>m.Role==HouseRole.OWNER).UserId,season_id=seasonId,revision=season.ScheduleRevision,source_sequence=house.AiTelemetrySequence,status=season.Status.ToString(),as_of=clock.GetUtcNow(),data_source=house.AiDataSource,members=memberData,tasks});
    }

    public string Fingerprint(JsonElement context)
    {
        var values=context.EnumerateObject().Where(p=>p.Name is not ("as_of" or "source_sequence")).ToDictionary(p=>p.Name,p=>p.Value);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(values))));
    }
}
