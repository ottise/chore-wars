namespace ChoreWars.Application.DTOs.Supplies;
public sealed record UpsertSupplyProductRequest(string Sku, string Name, string Unit, decimal Price, int AvailableQuantity, bool Active = true, uint? ExpectedVersion = null);
