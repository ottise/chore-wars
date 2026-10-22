namespace ChoreWars.Application.DTOs.AI;

public sealed class AIAvailabilityExceptionRequest
{
    public Guid SeasonId { get; set; }
    public DateOnly LocalDate { get; set; }
    public List<int[]> Slots { get; set; } = [];
}
