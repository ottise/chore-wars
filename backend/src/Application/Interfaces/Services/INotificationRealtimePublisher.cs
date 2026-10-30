using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Notification;

namespace ChoreWars.Application.Interfaces.Services;

public interface INotificationRealtimePublisher
{
    Task ChatUnreadChangedAsync(System.Guid userId, System.Guid houseId, CancellationToken ct = default) => Task.CompletedTask;
    Task PublishAsync(NotificationResponse notification, CancellationToken cancellationToken = default);
}