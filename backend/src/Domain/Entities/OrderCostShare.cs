using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class OrderCostShare {
public Guid Id { get; set; }
public Guid OrderId { get; set; }
public Guid UserId { get; set; }
public string DisplayName { get; set; } = "";
public decimal Amount { get; set; }
public DateTime? ApprovedAt { get; set; }
public DateTime? RejectedAt { get; set; }
}
