using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using System.Text.Json;

namespace ChoreWars.Application.Services.AI;

public sealed class ScheduleChangeService(IUnitOfWork uow, IAIContextBuilder contexts, TimeProvider clock, IAIStateRepository ai) : IScheduleChangeService
{
    public async Task<JsonElement> CandidateContextAsync(Guid house, Guid seasonId, JsonElement original, List<ScheduleAvailabilityChange> changes, CancellationToken ct) {
        if(changes.Count>31 || changes.Select(c=>(c.UserId,c.LocalDate)).Distinct().Count()!=changes.Count)throw new DomainException("Use at most 31 distinct member/date changes.");
        var season=await uow.Seasons.GetByIdAsync(seasonId,ct) ?? throw new NotFoundException("Season not found.");
        if(season.HouseId!=house)throw new NotFoundException("Season not found.");
        var members=original.GetProperty("members").EnumerateArray().ToDictionary(m=>m.GetProperty("id").GetGuid(),m=>m.EnumerateObject().ToDictionary(p=>p.Name,p=>p.Value));
        foreach(var change in changes) {
            if(!members.TryGetValue(change.UserId,out var member))throw new ConflictException("Availability change needs an active member.");
            if(change.LocalDate<DateOnly.FromDateTime(ScheduleTime.Local(clock.GetUtcNow().UtcDateTime)) || change.LocalDate<DateOnly.FromDateTime(ScheduleTime.Local(season.StartDate)) || change.LocalDate>DateOnly.FromDateTime(ScheduleTime.Local(season.EndDate)))throw new DomainException("Availability changes must be on a current/future date inside the season.");
            var slots=change.Slots.OrderBy(s=>s.StartMinute).ToList();
            for(var i=0;i<slots.Count;i++)if(slots[i].StartMinute<0 || slots[i].EndMinute>1440 || slots[i].StartMinute>=slots[i].EndMinute || i>0 && slots[i-1].EndMinute>slots[i].StartMinute)throw new DomainException("Availability windows must be valid and must not overlap.");
            var exceptions=member["date_exceptions"].EnumerateObject().ToDictionary(p=>p.Name,p=>p.Value);
            exceptions[change.LocalDate.ToString("yyyy-MM-dd")]=JsonSerializer.SerializeToElement(slots.Select(s=>new{start=s.StartMinute,end=s.EndMinute}));
            member["date_exceptions"]=JsonSerializer.SerializeToElement(exceptions);
        }
        var context=original.EnumerateObject().ToDictionary(p=>p.Name,p=>p.Value);context["members"]=JsonSerializer.SerializeToElement(members.Values);
        context["constraint_task_ids"]=JsonSerializer.SerializeToElement(original.GetProperty("tasks").EnumerateArray().Where(t=>t.GetProperty("status").GetString()=="ASSIGNED" && t.GetProperty("assigned_to").ValueKind!=JsonValueKind.Null && changes.Any(c=>c.UserId==t.GetProperty("assigned_to").GetGuid() && c.LocalDate==DateOnly.FromDateTime(ScheduleTime.Local(t.GetProperty("due_at").GetDateTime())))).Select(t=>t.GetProperty("id").GetGuid()));
        return JsonSerializer.SerializeToElement(context);
    }
    public async Task<IReadOnlySet<Guid>> ValidateAsync(Guid house, ScheduleChangePayload payload, CancellationToken ct)
    {
        var context=await contexts.BuildAsync(house,payload.SeasonId,ct);
        if (context.GetProperty("status").GetString()!="ACTIVE" || contexts.Fingerprint(context)!=payload.ContextHash)
            throw new ConflictException("Schedule context changed; request and review a new replan.");
        if (payload.Changes.Count>2000 || payload.Changes.Count==0 && payload.AvailabilityChanges.Count==0 || payload.Changes.Select(c=>c.OccurrenceId).Distinct().Count()!=payload.Changes.Count)
            throw new DomainException("Replan needs unique occurrence changes.");
        var byId=(await uow.ChoreOccurrences.GetBySeasonIdAsync(payload.SeasonId,ct)).Where(o=>o.Chore.Type==ChoreType.NORMAL).ToDictionary(o=>o.Id);
        var required=new HashSet<Guid>();
        var members=(await uow.HouseMembers.GetByHouseIdAsync(house,ct)).Where(m=>m.Status==HouseMemberStatus.ACTIVE).ToList();
        var owner=members.SingleOrDefault(m=>m.Role==HouseRole.OWNER) ?? throw new ConflictException("Active owner required.");
        required.Add(owner.UserId);
        var active=members.Select(m=>m.UserId).ToHashSet();
        foreach(var change in payload.AvailabilityChanges)required.Add(change.UserId);
        var candidateContext=await CandidateContextAsync(house,payload.SeasonId,context,payload.AvailabilityChanges,ct);
        var wire=context.GetProperty("tasks").EnumerateArray().ToDictionary(t=>t.GetProperty("id").GetGuid());
        var scratch=byId.Values.Select(o=>new ChoreOccurrence{Id=o.Id,ChoreId=o.ChoreId,SeasonId=o.SeasonId,Chore=o.Chore,DueDate=o.DueDate,AssignedUserId=o.AssignedUserId,PlannedStartAt=o.PlannedStartAt,SnapshotKarma=o.SnapshotKarma,SnapshotMinutes=o.SnapshotMinutes,Status=o.Status}).ToList();
        foreach (var change in payload.Changes)
        {
            if (!byId.TryGetValue(change.OccurrenceId,out var old) || wire[change.OccurrenceId].GetProperty("locked").GetBoolean() || !old.AssignedUserId.HasValue)
                throw new ConflictException("A replan occurrence is locked or unavailable.");
            if (!active.Contains(change.AssignedUserId) || change.PlannedStartAt.Kind!=DateTimeKind.Utc || change.PlannedStartAt<clock.GetUtcNow().UtcDateTime)
                throw new ConflictException("Replan needs active assignees and future UTC start times.");
            if (change.PreviousUserId!=old.AssignedUserId || change.PreviousStartAt!=old.PlannedStartAt || change.Name!=old.Chore.Name)
                throw new ConflictException("Replan before/after evidence no longer matches the schedule.");
            required.Add(old.AssignedUserId.Value);required.Add(change.AssignedUserId);
            var task=scratch.Single(o=>o.Id==change.OccurrenceId);task.AssignedUserId=change.AssignedUserId;task.PlannedStartAt=change.PlannedStartAt;
        }
        var validationScope=wire.Values.Where(t=>!t.GetProperty("locked").GetBoolean()).Select(t=>t.GetProperty("id").GetGuid()).Concat(payload.Changes.Select(c=>c.OccurrenceId)).ToHashSet();
        foreach(var item in scratch.Where(o=>o.Status==ChoreOccurrenceStatus.ASSIGNED && payload.AvailabilityChanges.Any(c=>c.UserId==o.AssignedUserId && c.LocalDate==DateOnly.FromDateTime(ScheduleTime.Local(o.DueDate)))))validationScope.Add(item.Id);
        await AIHousekeeperService.ValidateScheduleAsync(candidateContext,scratch,ct,validationScope);
        int Gap(IEnumerable<ChoreOccurrence> tasks) { var loads=active.Select(id=>tasks.Where(o=>o.AssignedUserId==id).Sum(o=>o.SnapshotKarma)).ToList();return loads.Max()-loads.Min(); }
        if (Gap(scratch)>Gap(byId.Values)) throw new ConflictException("Replan increases the assigned Karma gap.");
        return required;
    }

    public async Task ApplyAsync(Guid house, ScheduleChangePayload payload, CancellationToken ct)
    {
        await ValidateAsync(house,payload,ct);
        var exceptions=await ai.AvailabilityExceptionsAsync(payload.SeasonId,ct);
        foreach(var change in payload.AvailabilityChanges) {
            var row=exceptions.SingleOrDefault(e=>e.UserId==change.UserId && e.LocalDate==change.LocalDate);
            if(row==null) {row=new MemberAvailabilityException{Id=Guid.NewGuid(),SeasonId=payload.SeasonId,UserId=change.UserId,LocalDate=change.LocalDate};ai.AddAvailabilityException(row);}
            row.SlotsJson=JsonSerializer.Serialize(change.Slots.OrderBy(s=>s.StartMinute).Select(s=>new{start=s.StartMinute,end=s.EndMinute}));
        }
        var occurrences=(await uow.ChoreOccurrences.GetBySeasonIdAsync(payload.SeasonId,ct)).ToDictionary(o=>o.Id);
        var previous=payload.Changes.ToDictionary(c=>c.OccurrenceId,c=>occurrences[c.OccurrenceId].AssignedUserId);
        foreach (var change in payload.Changes.Where(c=>previous[c.OccurrenceId]!=c.AssignedUserId))
            await ChoreResponsibilityService.EnsureAsync(uow,occurrences[change.OccurrenceId],clock.GetUtcNow().UtcDateTime,ct);
        // Establish the complete post-change workload before capturing any new responsibility snapshot.
        foreach (var change in payload.Changes) {
            occurrences[change.OccurrenceId].AssignedUserId=change.AssignedUserId;
            occurrences[change.OccurrenceId].PlannedStartAt=change.PlannedStartAt;
        }
        foreach (var change in payload.Changes) {
            var task=occurrences[change.OccurrenceId];
            if (previous[change.OccurrenceId]!=change.AssignedUserId)
                await ChoreResponsibilityService.AssignAsync(uow,task,change.AssignedUserId,"REPLAN",task.DueDate,clock.GetUtcNow().UtcDateTime,ct);
            task.PlannedStartAt=change.PlannedStartAt;uow.ChoreOccurrences.Update(task);
        }
        var season=await uow.Seasons.GetByIdAsync(payload.SeasonId,ct) ?? throw new NotFoundException("Season not found.");
        season.ScheduleRevision++;uow.Seasons.Update(season);
    }
}
