namespace ChoreWars.Infrastructure.AI;

public sealed class AIOptions
{
    public bool Enabled { get; set; }
    public string BaseUrl { get; set; } = "http://ai-api:8000";
    public string ServiceKey { get; set; } = "";
    public int RequestTimeoutSeconds { get; set; } = 90;
}
