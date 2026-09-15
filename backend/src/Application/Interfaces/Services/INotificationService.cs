using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Notification;

namespace ChoreWars.Application.Interfaces.Services;

public interface INotificationService
{
    Task<IEnumerable<NotificationResponse>> GetNotificationsAsync(Guid userId, CancellationToken cancellationToken = default);
    Task MarkAsReadAsync(Guid notificationId, Guid userId, CancellationToken cancellationToken = default);
    Task MarkAllAsReadAsync(Guid userId, CancellationToken cancellationToken = default);
    Task CreateNotificationAsync(Guid userId, Guid houseId, string title, string message, string type, CancellationToken cancellationToken = default);
}
