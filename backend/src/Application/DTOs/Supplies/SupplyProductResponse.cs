namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyProductResponse(Guid Id, Guid SupplierId, string Sku, string Name, string Unit, decimal Price, int AvailableQuantity, bool Active, uint Version);
