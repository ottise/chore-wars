using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Common.Constants;
using System.Globalization;
namespace ChoreWars.Application.Services;

// Incremental allocation: never regenerate an approved schedule or change existing assignments.
public static class ChoreSchedulingService
{
    public static async Task AppendAsync(IUnitOfWork uow, Chore chore, ChoreSeason season, DateTime now, CancellationToken ct)
    {
        var all = (await uow.ChoreOccurrences.GetBySeasonIdAsync(season.Id, ct)).ToList();
        var from = DateOnly.FromDateTime(ScheduleTime.Local(season.StartDate));
        var to = DateOnly.FromDateTime(ScheduleTime.Local(season.EndDate));
        var days = RecurrenceCalculator.Dates(chore, from, to);
        var added = days.Select(day => new ChoreOccurrence
        {
            Id = Guid.NewGuid(),
            ChoreId = chore.Id,
            Chore = chore,
            SeasonId = season.Id,
            DueDate = ScheduleTime.Utc(day, chore.DeadlineMinutes),
            Status = ChoreOccurrenceStatus.ASSIGNED,
            SnapshotKarma = chore.KarmaPoints,
            SnapshotMinutes = ScheduleTime.Effort(chore.Difficulty),
            SnapshotDifficulty = chore.Difficulty
        }).Where(o => o.DueDate > now && o.DueDate >= season.StartDate && o.DueDate <= season.EndDate
            && !all.Any(old => old.ChoreId == chore.Id && old.DueDate == o.DueDate)).ToList();
        if (added.Count == 0) throw new ChoreWars.Domain.Exceptions.ConflictException("No future chores fall within this season. Choose a future date or an open season.");
        var members = (await uow.HouseMembers.GetByHouseIdAsync(season.HouseId, ct)).Where(m => m.Status == HouseMemberStatus.ACTIVE).ToList();
        var weekly = (await uow.MemberAvailabilities.GetBySeasonIdAsync(season.Id, ct)).ToList();
        var exceptions = (await uow.MemberAvailabilities.GetExceptionsBySeasonAsync(season.Id, ct)).ToList();
        foreach (var task in added.OrderBy(o => o.DueDate))
        {
            if (chore.Type == ChoreType.NORMAL && season.AllocationMethod == AllocationMethod.AUTOMATIC)
            {
                var choices = new List<(Guid User, DateTime Start, int Load)>();
                foreach (var member in members)
                {
                    var start = await AvailableStartAsync(uow, season.HouseId, task, member.UserId, all, weekly, exceptions, now, ct);
                    if (start.HasValue) choices.Add((member.UserId, start.Value, all.Where(o => o.AssignedUserId == member.UserId && o.Status != ChoreOccurrenceStatus.SKIPPED).Sum(o => Math.Max(1, o.SnapshotKarma))));
                }
                if (choices.Count > 0)
                {
                    var selected = choices.OrderBy(c => c.Load).ThenBy(c => c.User).First();
                    task.AssignedUserId = selected.User; task.PlannedStartAt = selected.Start;
                }
            }
            await uow.ChoreOccurrences.AddAsync(task, ct);
            all.Add(task);
            if (task.AssignedUserId.HasValue) await ChoreResponsibilityService.EnsureAsync(uow, task, now, ct);
        }
    }

    public static async Task<DateTime?> AvailableStartAsync(IUnitOfWork uow, Guid houseId, ChoreOccurrence task, Guid user,
        List<ChoreOccurrence> all, List<MemberAvailability> weekly, List<MemberAvailabilityException> exceptions, DateTime notBefore, CancellationToken ct)
    {
        var date = ScheduleTime.Local(task.DueDate);
        var assigned = all.Where(o => o.Id != task.Id && o.AssignedUserId == user && o.Status != ChoreOccurrenceStatus.SKIPPED).ToList();
        var limits = await uow.MemberConstraints.GetByUserAndHouseIdAsync(user, houseId, ct);
        if (assigned.Count(o => ISOWeek.GetYear(ScheduleTime.Local(o.DueDate)) == ISOWeek.GetYear(date) && ISOWeek.GetWeekOfYear(ScheduleTime.Local(o.DueDate)) == ISOWeek.GetWeekOfYear(date)) >= (limits?.MaxChoresPerWeek ?? AIAllocationConstants.DefaultMaxChoresPerWeek)) return null;
        if (assigned.Where(o => ScheduleTime.Local(o.DueDate).Date == date.Date).Sum(AllocationEligibilityService.Minutes) + AllocationEligibilityService.Minutes(task) > (limits?.MaxEffortMinutesPerDay ?? AIAllocationConstants.DefaultMaxEffortMinutesPerDay)) return null;
        var own = weekly.Where(a => a.UserId == user).ToList();
        var available = own.FirstOrDefault(a => a.DayOfWeek == date.DayOfWeek);
        if (own.Count == 0) available = new MemberAvailability { UserId = user, DayOfWeek = date.DayOfWeek, IsAvailable = true };
        available = AllocationEligibilityService.Effective(available, user, DateOnly.FromDateTime(date), exceptions);
        return AllocationEligibilityService.FindStart(task, available, assigned, notBefore);
    }
}
