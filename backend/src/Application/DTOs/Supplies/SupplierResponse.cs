namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierResponse(Guid Id, string Name, string Phone, string Email, string DeliveryArea, decimal DeliveryFee);
