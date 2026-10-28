namespace ChoreWars.Application.DTOs.House;
public sealed record HouseCalendarItemResponse(Guid Id, string ChoreName, string Status, string Type, DateTime DueDate,
    DateTime? CompletedAt, Guid? AssignedUserId, string? AssignedName, Guid? CompletedByUserId, string? CompletedByName, List<Guid> EvidenceIds);
