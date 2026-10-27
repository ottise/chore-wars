namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierCheckoutResult(string PaymentLinkId, string CheckoutUrl, string QrCode);
