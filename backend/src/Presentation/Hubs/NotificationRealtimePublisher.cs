using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.SignalR;

namespace ChoreWars.Presentation.Hubs;

public class NotificationRealtimePublisher : INotificationRealtimePublisher
{
    private readonly IHubContext<NotificationHub> _hubContext;

    public NotificationRealtimePublisher(IHubContext<NotificationHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task ChatUnreadChangedAsync(Guid userId, Guid houseId, CancellationToken ct = default) => _hubContext.Clients.User(userId.ToString()).SendAsync("ChatUnreadChanged", houseId.ToString(), ct);

    public Task PublishAsync(NotificationResponse notification, CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients
            .User(notification.UserId.ToString())
            .SendAsync("NotificationReceived", notification, cancellationToken);
    }
}