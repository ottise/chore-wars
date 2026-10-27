using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class SupplierPayment {
public Guid Id { get; set; }
public Guid OrderId { get; set; }
public long OrderCode { get; set; }
public string PaymentLinkId { get; set; } = "";
public string CheckoutUrl { get; set; } = "";
public string QrCode { get; set; } = "";
public string Reference { get; set; } = "";
public decimal Amount { get; set; }
public SupplierPaymentStatus Status { get; set; }
public DateTime CreatedAt { get; set; }
public DateTime ExpiresAt { get; set; }
}
