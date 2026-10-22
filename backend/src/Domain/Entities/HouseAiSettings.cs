namespace ChoreWars.Domain.Entities;

public sealed class HouseAiSettings
{
    public Guid HouseId { get; set; }
    public bool Enabled { get; set; }
    public bool ChatAutoInsightsEnabled { get; set; }
    public int Version { get; set; }
}
