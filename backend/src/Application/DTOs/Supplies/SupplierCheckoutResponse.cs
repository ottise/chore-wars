namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierCheckoutResponse(Guid PaymentId, string Status, string CheckoutUrl, string QrCode, DateTime ExpiresAt);
