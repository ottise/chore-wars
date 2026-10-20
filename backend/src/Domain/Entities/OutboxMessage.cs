namespace ChoreWars.Domain.Entities;
public class OutboxMessage {
    public string? MessageKey { get; set; }
    public Guid Id { get; set; }
    public string Topic { get; set; } = "";
    public string Payload { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime? PublishedAt { get; set; }
}
