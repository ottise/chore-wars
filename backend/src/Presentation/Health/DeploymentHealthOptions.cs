namespace ChoreWars.Presentation.Health;

public sealed class DeploymentHealthOptions
{
    public const string HeaderName = "X-Deployment-Key";
    public string Key { get; set; } = "";
}
