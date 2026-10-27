using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyRefundService {
 Task<List<SupplierRefundResponse>> ListAsync(Guid order,Guid actor,CancellationToken ct);
 Task<SupplierRefundResponse> ReportAsync(Guid order,Guid actor,SupplyRefundRequest request,CancellationToken ct);
 Task<SupplierRefundResponse> ConfirmAsync(Guid order,Guid refund,Guid actor,CancellationToken ct);
 Task<SupplierRefundResponse> RejectAsync(Guid order,Guid refund,Guid actor,CancellationToken ct);
}
