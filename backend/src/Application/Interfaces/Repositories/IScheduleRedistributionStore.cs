using ChoreWars.Domain.Entities;
namespace ChoreWars.Application.Interfaces.Repositories;

public interface IScheduleRedistributionStore
{
    Task<ScheduleRedistribution?> FindAsync(Guid houseId, Guid actor, Guid requestId, CancellationToken ct);
    Task AddAsync(ScheduleRedistribution row, CancellationToken ct);
}
