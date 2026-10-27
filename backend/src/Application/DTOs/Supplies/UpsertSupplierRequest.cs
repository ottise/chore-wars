namespace ChoreWars.Application.DTOs.Supplies;
public sealed record UpsertSupplierRequest(string Name, string Phone, string Email, string DeliveryArea, decimal DeliveryFee);
