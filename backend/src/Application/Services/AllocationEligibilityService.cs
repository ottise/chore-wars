using ChoreWars.Domain.Entities;
using System.Text.Json;
namespace ChoreWars.Application.Services;
public static class AllocationEligibilityService {
    public static MemberAvailability? Effective(MemberAvailability? weekly, Guid user, DateOnly date, IEnumerable<MemberAvailabilityException> exceptions) {
        var value=exceptions.SingleOrDefault(e=>e.UserId==user && e.LocalDate==date);
        if(value==null)return weekly;
        var slots=JsonSerializer.Deserialize<JsonElement>(value.SlotsJson).EnumerateArray().Select(s=>new MemberAvailabilitySlot{StartMinute=s.GetProperty("start").GetInt32(),EndMinute=s.GetProperty("end").GetInt32()}).ToList();
        return new MemberAvailability{UserId=user,SeasonId=value.SeasonId,DayOfWeek=date.DayOfWeek,IsAvailable=slots.Count>0,Slots=slots};
    }
    public static int Minutes(ChoreOccurrence o) => o.SnapshotMinutes > 0 ? o.SnapshotMinutes : ScheduleTime.Effort(o.Chore.Difficulty);
    public static DateTime? FindStart(ChoreOccurrence occurrence, MemberAvailability? availability, IEnumerable<ChoreOccurrence> assigned, DateTime? notBefore = null) {
        if (availability == null || !availability.IsAvailable) return null;
        var localDue = ScheduleTime.Local(occurrence.DueDate);
        var day = DateOnly.FromDateTime(localDue);
        var minutes = Minutes(occurrence);
        var windows = availability.Slots.Count > 0 ? availability.Slots.OrderBy(x => x.StartMinute).Select(x => (x.StartMinute, x.EndMinute)) : new[] { (0, 1440) }.AsEnumerable();
        foreach (var window in windows) {
            var start = ScheduleTime.Utc(day, window.Item1);
            if(notBefore.HasValue && start<notBefore.Value)start=notBefore.Value;
            var end = ScheduleTime.Utc(day, window.Item2);
            if (end > occurrence.DueDate) end = occurrence.DueDate;
            foreach (var other in assigned.Where(o => o.Id != occurrence.Id && o.PlannedStartAt.HasValue && o.Status is not (ChoreWars.Domain.Enums.ChoreOccurrenceStatus.COMPLETED or ChoreWars.Domain.Enums.ChoreOccurrenceStatus.SKIPPED)).OrderBy(o => o.PlannedStartAt)) {
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
