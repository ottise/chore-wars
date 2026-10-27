namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierPaymentResult(long OrderCode, string Status, decimal Amount, string PaymentLinkId, string Reference);
