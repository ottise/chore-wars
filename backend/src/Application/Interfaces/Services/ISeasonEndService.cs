using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface ISeasonEndService
{
    Task FinalizeSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task ProcessEndedSeasonsAsync(CancellationToken cancellationToken = default);
}
