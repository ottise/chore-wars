namespace ChoreWars.Domain.Entities;

public sealed class AIObservation
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid UserId { get; set; }
    public Guid ClientRequestId { get; set; }
    public Guid SeasonId { get; set; }
    public Guid OccurrenceId { get; set; }
    public Guid? BountyId { get; set; }
    public string Kind { get; set; } = "";
    public DateTime RecordedAt { get; set; }
}
