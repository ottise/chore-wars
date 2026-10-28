namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyOrderResponse(Guid Id, Guid HouseId, Guid SupplierId, string SupplierName, string SupplierPhone, Guid CreatorUserId, Guid PayerUserId, string Status, string CreatedVia, int Version, string DeliveryAddress, string ContactPhone, decimal Total, decimal DeliveryFee, decimal RefundedAmount, DateTime QuoteExpiresAt, DateTime CreatedAt, List<SupplyOrderLineResponse> Lines, List<OrderCostShareResponse> Shares,
    string Workflow = "LEGACY_SHARED", string SupplierEmail = "", string EmailStatus = "NOT_REQUESTED", string? EmailError = null,
    DateTime? EmailSentAt = null, decimal? RecordedPaidAmount = null, Guid? PaymentRecordedByUserId = null,
    DateTime? PaymentRecordedAt = null, string? PaymentConfirmationSource = null, string? PaymentReference = null,
    string Note = "", List<SupplyOrderActivityResponse>? Activities = null);
