namespace ChoreWars.Domain.Entities;

public sealed class AIResponsibilityContextSnapshot
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid EpisodeId { get; set; }
    public DateTime PredictionTime { get; set; }
    public DateTime CapturedAt { get; set; }
    public long SourceSequence { get; set; }
    public string ContextHash { get; set; } = "";
    public string PayloadJson { get; set; } = "{}";
}
