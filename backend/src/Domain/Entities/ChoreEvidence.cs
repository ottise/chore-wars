namespace ChoreWars.Domain.Entities;

public sealed class ChoreEvidence
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid OccurrenceId { get; set; }
    public Guid UploadedByUserId { get; set; }
    public Guid ClientRequestId { get; set; }
    public string StorageKey { get; set; } = "";
    public string ContentType { get; set; } = "";
    public string ContentHash { get; set; } = "";
    public string? VisionJson { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? AttachedAt { get; set; }
}
