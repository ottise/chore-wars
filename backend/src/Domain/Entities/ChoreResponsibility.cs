namespace ChoreWars.Domain.Entities;
public class ChoreResponsibility {
    public Guid Id { get; set; }
    public Guid OccurrenceId { get; set; }
    public Guid UserId { get; set; }
    public string Reason { get; set; } = "LEGACY";
    public DateTime StartedAt { get; set; }
    public DateTime Deadline { get; set; }
    public DateTime? EndedAt { get; set; }
    public int PenaltiesApplied { get; set; }
    public Guid? CompletedByUserId { get; set; }
}
