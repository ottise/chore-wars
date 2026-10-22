namespace ChoreWars.Domain.Entities;

public sealed class AIChatInsight
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid UserId { get; set; }
    public Guid MessageId { get; set; }
    public int ConsentVersion { get; set; }
    public string Status { get; set; } = "WAITING";
    public string ResultJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; }
    public DateTime? ProcessedAt { get; set; }
    public int Attempts { get; set; }
}
