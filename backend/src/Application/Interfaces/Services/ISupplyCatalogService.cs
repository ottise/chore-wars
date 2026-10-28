using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyCatalogService
{
    Task<List<SupplierResponse>> SuppliersAsync(CancellationToken ct);
    Task<List<SupplierResponse>> HouseSuppliersAsync(Guid house, Guid actor, CancellationToken ct);
    Task<ShopItemResponse> CreateShopItemAsync(Guid house, Guid actor, CreateShopItemRequest request, CancellationToken ct);
    Task<SupplierResponse?> OwnAsync(Guid actor, CancellationToken ct);
    Task<bool> CanOperateAsync(Guid actor, CancellationToken ct);
    Task<SupplierResponse> SaveAsync(Guid actor, UpsertSupplierRequest request, CancellationToken ct);
    Task<List<SupplyProductResponse>> ProductsAsync(Guid supplier, bool includeInactive, Guid actor, CancellationToken ct);
    Task<SupplyProductResponse> SaveProductAsync(Guid actor, Guid id, UpsertSupplyProductRequest request, CancellationToken ct);
    Task<List<SupplierOrderResponse>> OrdersAsync(Guid actor, CancellationToken ct);
    Task<SupplierOrderResponse> FulfillAsync(Guid actor, Guid id, string status, int version, CancellationToken ct);
}
