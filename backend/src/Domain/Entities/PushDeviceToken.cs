namespace ChoreWars.Domain.Entities;

public sealed class PushDeviceToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public string Platform { get; set; } = "ANDROID";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public User User { get; set; } = null!;
}
