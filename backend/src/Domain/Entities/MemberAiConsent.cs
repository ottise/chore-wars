namespace ChoreWars.Domain.Entities;

public sealed class MemberAiConsent
{
    public Guid HouseId { get; set; }
    public Guid UserId { get; set; }
    public bool ChatAnalysisEnabled { get; set; }
    public int Version { get; set; }
    public DateTime UpdatedAt { get; set; }
}
