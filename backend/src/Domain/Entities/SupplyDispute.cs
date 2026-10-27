namespace ChoreWars.Domain.Entities;
public sealed class SupplyDispute
{
 public Guid Id { get; set; }
 public Guid OrderId { get; set; }
 public Guid CreatorUserId { get; set; }
 public Guid ClientRequestId { get; set; }
 public Guid? ProductId { get; set; }
 public string Reason { get; set; } = "";
 public string? Resolution { get; set; }
 public DateTime CreatedAt { get; set; }
 public DateTime? ProposedAt { get; set; }
 public DateTime? AcceptedAt { get; set; }
}
