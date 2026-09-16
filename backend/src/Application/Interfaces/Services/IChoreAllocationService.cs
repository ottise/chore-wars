using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChoreAllocationService
{
    Task AllocateSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task AllocateAllActiveSeasonsAsync(CancellationToken cancellationToken = default);
    Task ManualAllocateAsync(Guid seasonId, Guid occurrenceId, Guid assigneeId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<string>> GetFairnessWarningsAsync(Guid seasonId, CancellationToken cancellationToken = default);
}
