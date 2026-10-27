using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class PaymentWebhookReceipt {
public Guid Id { get; set; }
public Guid PaymentId { get; set; }
public string Reference { get; set; } = "";
public DateTime ReceivedAt { get; set; }
}
