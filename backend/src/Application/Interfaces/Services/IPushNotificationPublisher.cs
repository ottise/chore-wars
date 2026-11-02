using ChoreWars.Application.DTOs.Notification;

namespace ChoreWars.Application.Interfaces.Services;

public interface IPushNotificationPublisher
{
    Task PublishAsync(NotificationResponse notification, CancellationToken cancellationToken = default);
}
