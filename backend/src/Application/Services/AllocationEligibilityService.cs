using ChoreWars.Domain.Entities;
namespace ChoreWars.Application.Services;
public static class AllocationEligibilityService {
    public static int Minutes(ChoreOccurrence o) => o.SnapshotMinutes > 0 ? o.SnapshotMinutes : ScheduleTime.Effort(o.Chore.Difficulty);
    public static DateTime? FindStart(ChoreOccurrence occurrence, MemberAvailability? availability, IEnumerable<ChoreOccurrence> assigned) {
        if (availability == null || !availability.IsAvailable) return null;
        var localDue = ScheduleTime.Local(occurrence.DueDate);
        var day = DateOnly.FromDateTime(localDue);
        var minutes = Minutes(occurrence);
        var windows = availability.Slots.Count > 0 ? availability.Slots.OrderBy(x => x.StartMinute).Select(x => (x.StartMinute, x.EndMinute)) : new[] { (0, 1440) }.AsEnumerable();
        foreach (var window in windows) {
            var start = ScheduleTime.Utc(day, window.Item1);
            var end = ScheduleTime.Utc(day, window.Item2);
            if (end > occurrence.DueDate) end = occurrence.DueDate;
            foreach (var other in assigned.Where(o => o.Id != occurrence.Id && o.PlannedStartAt.HasValue).OrderBy(o => o.PlannedStartAt)) {
                var occupiedStart = other.PlannedStartAt!.Value;
                var occupiedEnd = occupiedStart.AddMinutes(Minutes(other));
                if (occupiedEnd <= start || occupiedStart >= end) continue;
                if (start.AddMinutes(minutes) <= occupiedStart) break;
                if (occupiedEnd > start) start = occupiedEnd;
            }
            if (start.AddMinutes(minutes) <= end) return start;
        }
        return null;
    }
}
