namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierCheckoutRequest(long OrderCode, decimal Amount, string Description, DateTime ExpiresAt, Guid OrderId, Guid HouseId);
