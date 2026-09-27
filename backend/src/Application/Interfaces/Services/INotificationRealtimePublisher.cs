using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Notification;

namespace ChoreWars.Application.Interfaces.Services;

public interface INotificationRealtimePublisher
{
    Task PublishAsync(NotificationResponse notification, CancellationToken cancellationToken = default);
}