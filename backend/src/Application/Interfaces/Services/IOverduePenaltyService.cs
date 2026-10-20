using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IOverduePenaltyService
{
    Task ApplyUntilAsync(Guid occurrenceId, DateTime cutoff, CancellationToken cancellationToken = default);
    Task ProcessOverduePenaltiesAsync(CancellationToken cancellationToken = default);
}
