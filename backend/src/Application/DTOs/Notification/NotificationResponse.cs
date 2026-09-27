using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Notification;

public class NotificationResponse
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? TargetType { get; set; }
    public Guid? TargetId { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }
}
