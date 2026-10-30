using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Infrastructure.Repositories;

public sealed class ScheduleRedistributionStore(AppDbContext db) : IScheduleRedistributionStore
{
    public Task<ScheduleRedistribution?> FindAsync(Guid houseId, Guid actor, Guid requestId, CancellationToken ct) =>
        db.Set<ScheduleRedistribution>().FirstOrDefaultAsync(x => x.HouseId == houseId && x.ActorId == actor && x.ClientRequestId == requestId, ct);
    public async Task AddAsync(ScheduleRedistribution row, CancellationToken ct) => await db.Set<ScheduleRedistribution>().AddAsync(row, ct);
}
