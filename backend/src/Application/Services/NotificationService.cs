using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class NotificationService : INotificationService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly INotificationRealtimePublisher _realtimePublisher;

    public NotificationService(IUnitOfWork unitOfWork, IMapper mapper, INotificationRealtimePublisher realtimePublisher)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _realtimePublisher = realtimePublisher;
    }

    public async Task<IEnumerable<NotificationResponse>> GetNotificationsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var notifications = await _unitOfWork.Notifications.GetByUserIdAsync(userId, cancellationToken);
        return _mapper.Map<IEnumerable<NotificationResponse>>(notifications);
    }

    public async Task MarkAsReadAsync(Guid notificationId, Guid userId, CancellationToken cancellationToken = default)
    {
        var notification = await _unitOfWork.Notifications.GetByIdAsync(notificationId, cancellationToken);
        if (notification == null)
            throw new NotFoundException("Notification not found.");

        if (notification.UserId != userId)
            throw new ForbiddenException();

        notification.IsRead = true;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Notifications.Update(notification);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task MarkAllAsReadAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var notifications = await _unitOfWork.Notifications.GetUnreadByUserIdAsync(userId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            foreach (var notification in notifications)
            {
                notification.IsRead = true;
                _unitOfWork.Notifications.Update(notification);
            }
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task CreateNotificationAsync(Guid userId, Guid houseId, string title, string message, string type, string? targetType = null, Guid? targetId = null, CancellationToken cancellationToken = default)
    {
        var notification = new ChoreWars.Domain.Entities.Notification
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            HouseId = houseId,
            Title = title,
            Message = message,
            TargetType = targetType,
            TargetId = targetId,
            Type = Enum.Parse<ChoreWars.Domain.Enums.NotificationType>(type, true),
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };

        await _unitOfWork.Notifications.AddAsync(notification, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        await _realtimePublisher.PublishAsync(_mapper.Map<NotificationResponse>(notification), cancellationToken);
    }
}
