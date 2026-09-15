using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface ISeasonEndService
{
    Task ProcessEndedSeasonsAsync(CancellationToken cancellationToken = default);
}
