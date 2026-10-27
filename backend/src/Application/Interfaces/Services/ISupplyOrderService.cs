using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyOrderService
{
    Task<List<SupplyOrderResponse>> ListAsync(Guid house, Guid actor, CancellationToken ct);
    Task<SupplyOrderResponse> ReadAsync(Guid house, Guid id, Guid actor, CancellationToken ct);
    Task<SupplyOrderResponse> CreateAsync(Guid house, Guid actor, CreateSupplyOrderRequest request, CancellationToken ct);
    Task<SupplyOrderResponse> ReviseAsync(Guid house,Guid id,Guid actor,ReviseSupplyOrderRequest request,CancellationToken ct);
    Task<SupplyOrderResponse> SubmitAsync(Guid house, Guid id, Guid actor, int version, CancellationToken ct);
    Task<SupplyOrderResponse> DecideAsync(Guid house, Guid id, Guid actor, SupplyDecisionRequest request, CancellationToken ct);
    Task<SupplyOrderResponse> CancelAsync(Guid house, Guid id, Guid actor, int version, CancellationToken ct);
    Task<SupplyOrderResponse> ReceiveAsync(Guid house, Guid id, Guid actor, int version, CancellationToken ct);
    Task ExpireAsync(Guid id,CancellationToken ct);
}
