namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyOrderActivityResponse(string Kind, Guid? ActorUserId, DateTime RecordedAt, decimal? Amount, string? Reference);
