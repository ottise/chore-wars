using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
namespace ChoreWars.Application.Services;
public static class ReplacementSelector {
    public static async Task<Guid?> SelectAsync(IUnitOfWork uow, ChoreOccurrence occurrence, Guid excluded, CancellationToken ct) {
        var houseId = occurrence.Chore.HouseId;
        var members = (await uow.HouseMembers.GetByHouseIdAsync(houseId, ct)).Where(m => m.Status == HouseMemberStatus.ACTIVE && m.UserId != excluded);
        var all = (await uow.ChoreOccurrences.GetBySeasonIdAsync(occurrence.SeasonId, ct)).Where(o => o.Id != occurrence.Id && o.Chore.Type == ChoreType.NORMAL).ToList();
        var availability = await uow.MemberAvailabilities.GetBySeasonIdAsync(occurrence.SeasonId, ct);
        var day = ScheduleTime.Local(occurrence.DueDate);
        foreach (var member in members.OrderBy(m => all.Where(o => o.AssignedUserId == m.UserId).Sum(o => o.SnapshotKarma)).ThenBy(m => m.UserId)) {
            var assigned = all.Where(o => o.AssignedUserId == member.UserId).ToList();
            var limit = await uow.MemberConstraints.GetByUserAndHouseIdAsync(member.UserId, houseId, ct);
            if (assigned.Count(o => { var d = ScheduleTime.Local(o.DueDate); return System.Globalization.ISOWeek.GetYear(d) == System.Globalization.ISOWeek.GetYear(day) && System.Globalization.ISOWeek.GetWeekOfYear(d) == System.Globalization.ISOWeek.GetWeekOfYear(day); }) >= (limit?.MaxChoresPerWeek ?? 20)) continue;
            if (assigned.Where(o => ScheduleTime.Local(o.DueDate).Date == day.Date).Sum(AllocationEligibilityService.Minutes) + AllocationEligibilityService.Minutes(occurrence) > (limit?.MaxEffortMinutesPerDay ?? 120)) continue;
            if (AllocationEligibilityService.FindStart(occurrence, availability.FirstOrDefault(a => a.UserId == member.UserId && a.DayOfWeek == day.DayOfWeek), assigned) != null) return member.UserId;
        }
        return null;
    }
}
