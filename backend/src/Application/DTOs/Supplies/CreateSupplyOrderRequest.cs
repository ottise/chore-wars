namespace ChoreWars.Application.DTOs.Supplies;
public sealed record CreateSupplyOrderRequest(Guid ClientRequestId, Guid SupplierId, Guid PayerUserId, string DeliveryAddress, string ContactPhone, List<SupplyOrderLineRequest> Lines, List<OrderCostShareRequest> Shares, bool ViaAI = false);
