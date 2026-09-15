using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces;

public interface IEventPublisher
{
    Task PublishAsync<T>(T @event, CancellationToken cancellationToken = default);
}
