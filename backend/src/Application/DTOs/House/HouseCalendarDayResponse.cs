namespace ChoreWars.Application.DTOs.House;
public sealed record HouseCalendarDayResponse(DateOnly Date, int ScheduledCount, int CompletedCount, int OverdueCount,
    int TotalEvidenceCount, List<Guid> PreviewEvidenceIds, List<HouseCalendarItemResponse> Items);
