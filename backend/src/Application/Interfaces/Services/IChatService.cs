using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Chat;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChatService
{
    Task<bool> GetNotificationsEnabledAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task SetNotificationsEnabledAsync(Guid houseId, Guid userId, bool enabled, CancellationToken cancellationToken = default);
    Task<ChatRoomResponse> GetHouseRoomAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<PagedResult<ChatMessageResponse>> GetMessagesAsync(Guid roomId, Guid userId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<ChatMessageResponse> CreateMessageAsync(Guid roomId, Guid userId, string content, CancellationToken cancellationToken = default);
    Task<ChatMessageResponse> CreateTextMessageAsync(Guid roomId, Guid userId, string content, Guid clientMessageId, CancellationToken cancellationToken = default);
    Task EnsureRoomAccessAsync(Guid roomId, Guid userId, CancellationToken cancellationToken = default);
}
