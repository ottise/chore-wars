namespace ChoreWars.Application.DTOs.AI;

public sealed class AIAvailabilityChangeRequest
{
    public Guid ClientRequestId { get; set; }
    public Guid SeasonId { get; set; }
    public DateOnly LocalDate { get; set; }
    public bool Busy { get; set; }
    public int StartMinute { get; set; }
    public int EndMinute { get; set; }
    public Guid? InsightId { get; set; }
}
