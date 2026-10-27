using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyDisputeService{
 Task<List<SupplyDisputeResponse>> ListAsync(Guid order,Guid actor,CancellationToken ct);
 Task<SupplyDisputeResponse> CreateAsync(Guid order,Guid actor,CreateSupplyDisputeRequest request,CancellationToken ct);
 Task<SupplyDisputeResponse> ProposeAsync(Guid order,Guid dispute,Guid actor,ProposeSupplyResolutionRequest request,CancellationToken ct);
 Task<SupplyDisputeResponse> AcceptAsync(Guid order,Guid dispute,Guid actor,CancellationToken ct);
}
