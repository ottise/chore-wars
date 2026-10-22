using System.Text.Json;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services.AI;

public sealed class UrgentPlanValidation(IUnitOfWork uow, IAIContextBuilder contexts, TimeProvider clock) : IUrgentPlanValidation
{
    public async Task ValidateAsync(Guid house, UrgentEventPayload payload, CancellationToken ct)
    {
        if(payload.PlanVersion!="blitz-v1")throw new DomainException("Unsupported urgent plan version.");
        var byKey=new Dictionary<string,UrgentChoreItem>();
        foreach(var item in payload.Chores) {
            if(string.IsNullOrWhiteSpace(item.PlanKey) || item.PlanKey.Length>40 || !byKey.TryAdd(item.PlanKey,item) || item.PlannedOffsetMinutes<0 || item.PlannedOffsetMinutes+ScheduleTime.Effort(item.Difficulty)>payload.DeadlineMinutes || item.Resources.Count>10 || item.Resources.Any(r=>string.IsNullOrWhiteSpace(r)||r.Length>100))throw new DomainException("Invalid urgent timeline.");
        }
        foreach(var item in payload.Chores) {
            foreach(var dependency in item.DependsOn) {
                if(!byKey.TryGetValue(dependency,out var predecessor) || dependency==item.PlanKey || predecessor.PlannedOffsetMinutes+ScheduleTime.Effort(predecessor.Difficulty)>item.PlannedOffsetMinutes)throw new ConflictException("Dependency order is infeasible.");
            }
            foreach(var other in payload.Chores.Where(c=>c!=item)) {
                var intersects=item.PlannedOffsetMinutes<other.PlannedOffsetMinutes+ScheduleTime.Effort(other.Difficulty) && other.PlannedOffsetMinutes<item.PlannedOffsetMinutes+ScheduleTime.Effort(item.Difficulty);
                if(intersects && (item.AssignedUserId==other.AssignedUserId || item.Resources.Intersect(other.Resources).Any()))throw new ConflictException("Urgent plan overlaps a participant or resource.");
            }
        }
        var context=await contexts.BuildAsync(house,payload.SeasonId,ct);
        var now=clock.GetUtcNow().UtcDateTime;
        var occurrences=(await uow.ChoreOccurrences.GetBySeasonIdAsync(payload.SeasonId,ct)).Where(o=>o.Chore.Type==ChoreType.NORMAL).ToList();
        var additions=payload.Chores.Select(item=>new ChoreOccurrence{Id=Guid.NewGuid(),SeasonId=payload.SeasonId,AssignedUserId=item.AssignedUserId,PlannedStartAt=now.AddMinutes(item.PlannedOffsetMinutes),DueDate=now.AddMinutes(payload.DeadlineMinutes),SnapshotMinutes=ScheduleTime.Effort(item.Difficulty),SnapshotKarma=item.KarmaPoints,Chore=new Chore{Difficulty=item.Difficulty}}).ToList();
        await AIHousekeeperService.ValidateScheduleAsync(context,occurrences.Concat(additions).ToList(),ct,additions.Select(o=>o.Id).ToHashSet());
    }
}
