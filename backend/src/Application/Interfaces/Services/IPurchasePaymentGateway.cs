using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface IPurchasePaymentGateway {
 void EnsureConfigured();
 Task<SupplierCheckoutResult> CreateAsync(SupplierCheckoutRequest request, CancellationToken ct);
 Task<SupplierPaymentResult> QueryAsync(long orderCode, CancellationToken ct);
 Task<SupplierPaymentResult> VerifyAsync(JsonElement webhook, CancellationToken ct);
}
