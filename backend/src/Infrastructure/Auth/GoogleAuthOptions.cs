namespace ChoreWars.Infrastructure.Auth;

public sealed class GoogleAuthOptions
{
    public const string Section = "GoogleAuth";
    public bool Enabled { get; set; }
    public string[] ClientIds { get; set; } = [];
}
