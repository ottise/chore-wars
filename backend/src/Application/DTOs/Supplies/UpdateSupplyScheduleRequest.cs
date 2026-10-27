namespace ChoreWars.Application.DTOs.Supplies;
public sealed record UpdateSupplyScheduleRequest(int ExpectedVersion, bool Enabled, DateTime? SnoozedUntil = null);
