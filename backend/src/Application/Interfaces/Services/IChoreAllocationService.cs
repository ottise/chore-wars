using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChoreAllocationService
{
    Task AllocateChoresAsync(CancellationToken cancellationToken = default);
}
