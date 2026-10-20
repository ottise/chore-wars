namespace ChoreWars.Domain.Entities;
public class MediaAttachment {
    public Guid Id { get; set; }
    public Guid RoomId { get; set; }
    public Guid OwnerId { get; set; }
    public string StorageKey { get; set; } = "";
    public string ContentType { get; set; } = "";
    public string Type { get; set; } = "";
    public long Size { get; set; }
    public int? DurationSeconds { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? AttachedAt { get; set; }
}
