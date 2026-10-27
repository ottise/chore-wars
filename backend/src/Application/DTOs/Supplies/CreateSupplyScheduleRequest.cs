namespace ChoreWars.Application.DTOs.Supplies;
public sealed record CreateSupplyScheduleRequest(Guid ClientRequestId, string Items, int DayOfMonth, int Hour, int Minute, int QuietFromHour = 22, int QuietToHour = 8);
