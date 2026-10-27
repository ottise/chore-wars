using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplierPaymentService
{
 Task<SupplierCheckoutResponse> CheckoutAsync(Guid house,Guid order,Guid actor,int version,CancellationToken ct);
 Task<SupplierCheckoutResponse?> RefreshAsync(Guid house,Guid order,Guid actor,CancellationToken ct);
 Task WebhookAsync(JsonElement payload,CancellationToken ct);
 Task ReconcileAsync(Guid payment,CancellationToken ct);
}
