namespace ChoreWars.Application.DTOs.Supplies;

public sealed record CreateShopItemRequest(Guid ClientRequestId, string Name, string Unit,
    decimal Price, string ContactName, string Phone, string Email);
public sealed record ShopItemResponse(SupplierResponse Supplier, SupplyProductResponse Product);
