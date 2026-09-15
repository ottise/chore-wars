using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChoreAllocationService
{
    Task AllocateSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task AllocateAllActiveSeasonsAsync(CancellationToken cancellationToken = default);
}
