using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyReminderService {
 Task<List<SupplyScheduleResponse>> ListAsync(Guid house,Guid actor,CancellationToken ct);
 Task<SupplyScheduleResponse> CreateAsync(Guid house,Guid actor,CreateSupplyScheduleRequest request,CancellationToken ct);
 Task<SupplyScheduleResponse> UpdateAsync(Guid house,Guid id,Guid actor,UpdateSupplyScheduleRequest request,CancellationToken ct);
 Task ProcessAsync(Guid schedule,CancellationToken ct);
}
