using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChatRepository
{
    Task<ChatRoom?> GetRoomByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<ChatRoom?> GetRoomByIdAsync(Guid roomId, CancellationToken cancellationToken = default);
    Task AddRoomAsync(ChatRoom room, CancellationToken cancellationToken = default);
    Task AddMessageAsync(ChatMessage message, CancellationToken cancellationToken = default);
    Task<List<ChatMessage>> GetMessagesPagedAsync(Guid roomId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> GetMessageCountAsync(Guid roomId, CancellationToken cancellationToken = default);
}
