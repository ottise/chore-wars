namespace ChoreWars.Application.Services;
public static class ScheduleTime {
    public static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");
    public static DateTime Local(DateTime instant) => TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(instant, DateTimeKind.Utc), Zone);
    public static DateTime Utc(DateOnly day, int minute) => TimeZoneInfo.ConvertTimeToUtc(day.ToDateTime(TimeOnly.MinValue).AddMinutes(minute), Zone);
    public static int Effort(ChoreWars.Domain.Enums.ChoreEffort difficulty) => difficulty switch {
        ChoreWars.Domain.Enums.ChoreEffort.EASY => 15, ChoreWars.Domain.Enums.ChoreEffort.HARD => 45, _ => 30 };
}
