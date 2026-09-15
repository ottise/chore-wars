using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IOverduePenaltyService
{
    Task ProcessOverduePenaltiesAsync(CancellationToken cancellationToken = default);
}
