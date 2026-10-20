namespace ChoreWars.Domain.Entities;
public class ProcessedMessage {
    public string Id { get; set; } = "";
    public string Consumer { get; set; } = "";
    public DateTime ProcessedAt { get; set; }
}
