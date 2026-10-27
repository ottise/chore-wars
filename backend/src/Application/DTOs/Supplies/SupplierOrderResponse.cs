namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierOrderResponse(Guid Id, string Status, int Version, string DeliveryAddress, string ContactPhone,
 decimal Total, decimal RefundedAmount, DateTime CreatedAt, List<SupplyOrderLineResponse> Lines);
