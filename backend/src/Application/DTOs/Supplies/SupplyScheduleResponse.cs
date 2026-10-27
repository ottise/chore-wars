namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyScheduleResponse(Guid Id, string Items, int DayOfMonth, int Hour, int Minute, string TimeZone, bool Enabled, DateTime NextDueAt, DateTime? SnoozedUntil, int Version);
