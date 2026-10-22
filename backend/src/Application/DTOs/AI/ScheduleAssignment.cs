namespace ChoreWars.Application.DTOs.AI;

public sealed class ScheduleAssignment
{
    public Guid OccurrenceId { get; set; }
    public Guid AssignedUserId { get; set; }
    public Guid PreviousUserId { get; set; }
    public DateTime? PreviousStartAt { get; set; }
    public string Name { get; set; } = "";
    public DateTime PlannedStartAt { get; set; }
}
