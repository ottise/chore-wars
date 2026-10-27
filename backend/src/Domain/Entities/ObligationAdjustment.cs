using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class ObligationAdjustment {
public Guid Id { get; set; }
public Guid ObligationId { get; set; }
public Guid SourceOrderId { get; set; }
public decimal Amount { get; set; }
public Guid ActorUserId { get; set; }
public string Reason { get; set; } = "";
public DateTime CreatedAt { get; set; }
}
