using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IBountyExpirationService
{
    Task ProcessExpiredBountiesAsync(CancellationToken cancellationToken = default);
}
