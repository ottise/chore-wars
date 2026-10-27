namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyOrderLineResponse(Guid ProductId, string Name, string Unit, decimal UnitPrice, int Quantity);
