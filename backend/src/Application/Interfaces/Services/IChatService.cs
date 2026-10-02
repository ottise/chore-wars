using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Chat;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChatService
{
    Task<ChatRoomResponse> GetHouseRoomAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<PagedResult<ChatMessageResponse>> GetMessagesAsync(Guid roomId, Guid userId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<ChatMessageResponse> CreateMessageAsync(Guid roomId, Guid userId, string content, CancellationToken cancellationToken = default);
}
