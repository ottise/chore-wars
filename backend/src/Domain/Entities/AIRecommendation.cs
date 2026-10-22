namespace ChoreWars.Domain.Entities;

public sealed class AIRecommendation
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid ActorId { get; set; }
    public Guid SeasonId { get; set; }
    public Guid ClientRequestId { get; set; }
    public string InputHash { get; set; } = "";
    public string ContextHash { get; set; } = "";
    public string Kind { get; set; } = "";
    public string Status { get; set; } = "";
    public string PayloadJson { get; set; } = "{}";
    public string AvailabilityChangesJson { get; set; } = "[]";
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public Guid? ProposalId { get; set; }
}
