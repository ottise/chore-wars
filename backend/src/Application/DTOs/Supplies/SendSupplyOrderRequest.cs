namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SendSupplyOrderRequest(Guid ClientRequestId, Guid SupplierId, List<SupplyOrderLineRequest> Lines,
    string DeliveryAddress = "", string ContactPhone = "", string Note = "", bool ViaAI = false,
    List<OrderCostShareRequest>? Shares = null);
