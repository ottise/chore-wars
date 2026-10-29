using System.Globalization;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.Services;

public sealed class MembershipChoreRedistributor(IUnitOfWork uow, TimeProvider clock,
    INotificationService notifications) : IMembershipChoreRedistributor
{
    public async Task RedistributeAsync(Guid houseId, Guid newUserId, CancellationToken ct)
    {
        var season = await uow.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, ct);
        if (season?.Status != SeasonStatus.ACTIVE) return;
        var now = clock.GetUtcNow().UtcDateTime;
        var members = (await uow.HouseMembers.GetByHouseIdAsync(houseId, ct))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE).Select(m => m.UserId).ToHashSet();
        if (!members.Contains(newUserId)) return;
        var all = (await uow.ChoreOccurrences.GetBySeasonIdAsync(season.Id, ct)).ToList();
        var obligations = (await uow.PaymentObligations.GetByHouseIdAsync(houseId, ct))
            .Where(p => p.OccurrenceId.HasValue).Select(p => p.OccurrenceId!.Value).ToHashSet();
        var candidates = new List<ChoreOccurrence>();
        foreach (var task in all.Where(o => o.Chore.Type == ChoreType.NORMAL &&
            o.Status == ChoreOccurrenceStatus.ASSIGNED && o.AssignedUserId.HasValue &&
            members.Contains(o.AssignedUserId.Value) && o.DueDate > now &&
            (!o.PlannedStartAt.HasValue || o.PlannedStartAt > now) &&
            o.PenaltyCount == 0 && !o.IsForcedReassigned && !o.EvidenceId.HasValue &&
            string.IsNullOrEmpty(o.ProofImageUrl) && !obligations.Contains(o.Id)))
        {
            if (await uow.ChoreBounties.GetByOccurrenceIdAsync(task.Id, ct) == null) candidates.Add(task);
        }
        var weekly = (await uow.MemberAvailabilities.GetBySeasonIdAsync(season.Id, ct))
            .Where(a => a.UserId == newUserId).ToList();
        var exceptions = await uow.MemberAvailabilities.GetExceptionsBySeasonAsync(season.Id, ct);
        var limits = await uow.MemberConstraints.GetByUserAndHouseIdAsync(newUserId, houseId, ct);
        var changed = new Dictionary<Guid, Guid>();
        int Load(Guid user) => candidates.Where(o => o.AssignedUserId == user)
            .Sum(o => Math.Max(1, o.SnapshotKarma));
        // Transfer only when the remaining workload becomes more balanced. Keep the existing time slots.
        foreach (var task in candidates.OrderBy(o => o.DueDate).ThenBy(o => o.Id))
        {
            var previous = task.AssignedUserId!.Value;
            if (previous == newUserId || Load(previous) - Load(newUserId) <= Math.Max(1, task.SnapshotKarma)) continue;
            var start = task.PlannedStartAt ?? task.DueDate.AddMinutes(-AllocationEligibilityService.Minutes(task));
            if (start <= now) continue;
            var local = ScheduleTime.Local(task.DueDate);
            var assigned = all.Where(o => o.AssignedUserId == newUserId).ToList();
            if (assigned.Count(o => ISOWeek.GetYear(ScheduleTime.Local(o.DueDate)) == ISOWeek.GetYear(local) &&
                ISOWeek.GetWeekOfYear(ScheduleTime.Local(o.DueDate)) == ISOWeek.GetWeekOfYear(local)) >=
                (limits?.MaxChoresPerWeek ?? AIAllocationConstants.DefaultMaxChoresPerWeek)) continue;
            if (assigned.Where(o => ScheduleTime.Local(o.DueDate).Date == local.Date).Sum(AllocationEligibilityService.Minutes) +
                AllocationEligibilityService.Minutes(task) > (limits?.MaxEffortMinutesPerDay ?? AIAllocationConstants.DefaultMaxEffortMinutesPerDay)) continue;
            var availability = weekly.FirstOrDefault(a => a.DayOfWeek == local.DayOfWeek);
            // A newcomer with no declaration inherits the household's existing time slots.
            // An explicit unavailable day or date exception is never overridden.
            if (weekly.Count == 0) availability = new MemberAvailability { UserId = newUserId, IsAvailable = true, DayOfWeek = local.DayOfWeek };
            availability = AllocationEligibilityService.Effective(availability, newUserId, DateOnly.FromDateTime(local), exceptions);
            if (AllocationEligibilityService.FindStart(task, availability, assigned, start) != start) continue;
            await ChoreResponsibilityService.AssignAsync(uow, task, newUserId, "MEMBER_JOINED", task.DueDate, now, ct);
            task.PlannedStartAt = start;
            uow.ChoreOccurrences.Update(task);
            changed.TryAdd(previous, task.Id);
            changed.TryAdd(newUserId, task.Id);
        }
        if (changed.Count == 0) return;
        season.ScheduleRevision++;
        uow.Seasons.Update(season);
        foreach (var (user, task) in changed)
            await notifications.CreateNotificationAsync(user, houseId, "Chore schedule updated",
                "A member joined. Remaining chores were shared again. Check your chores for your updated assignments.",
                nameof(NotificationType.CHORE_ASSIGNED), "CHORE", task, ct);
    }
}
