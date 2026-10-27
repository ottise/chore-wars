namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyOrderLineRequest(Guid ProductId, int Quantity);
