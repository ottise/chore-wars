namespace ChoreWars.Application.DTOs.AI;

public sealed class ScheduleChangePayload
{
    public Guid SeasonId { get; set; }
    public string ContextHash { get; set; } = "";
    public List<ScheduleAssignment> Changes { get; set; } = [];
    public List<ScheduleAvailabilityChange> AvailabilityChanges { get; set; } = [];
}
