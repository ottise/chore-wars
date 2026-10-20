namespace ChoreWars.Domain.Entities;

public class FailedEvent
{
    public Guid Id { get; set; }
    public string Identity { get; set; } = "";
    public string ConsumerGroup { get; set; } = "";
    public string Topic { get; set; } = "";
    public string EventKey { get; set; } = "";
    public string Payload { get; set; } = "";
    public int Partition { get; set; }
    public long Offset { get; set; }
    public Guid? HouseId { get; set; }
    public string ErrorCode { get; set; } = "";
    public string Status { get; set; } = "FAILED";
    public int FailureCount { get; set; }
    public DateTime FirstFailedAt { get; set; }
    public DateTime LastFailedAt { get; set; }
    public DateTime? ResolvedAt { get; set; }
}

public class FailedEventReplay
{
    public Guid Id { get; set; }
    public Guid FailedEventId { get; set; }
    public Guid RequestedByUserId { get; set; }
    public Guid OutboxId { get; set; }
    public DateTime RequestedAt { get; set; }
}
