using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISimpleSupplyOrderService
{
    Task<SupplyOrderResponse> SendAsync(Guid house, Guid actor, SendSupplyOrderRequest request, CancellationToken ct);
    Task<SupplyOrderResponse> RetryEmailAsync(Guid house, Guid order, Guid actor, CancellationToken ct);
    Task<SupplyOrderResponse> RecordPaymentAsync(Guid house, Guid order, Guid actor, RecordSupplyOrderPaymentRequest request, CancellationToken ct);
}
