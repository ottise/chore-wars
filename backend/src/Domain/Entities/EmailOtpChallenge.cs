namespace ChoreWars.Domain.Entities;

public sealed class EmailOtpChallenge
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Purpose { get; set; } = "";
    public string CodeHash { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? ConsumedAt { get; set; }
    public int FailedAttempts { get; set; }
}
