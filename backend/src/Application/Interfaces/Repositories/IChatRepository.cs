using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChatRepository
{
    Task AddAttachmentAsync(MediaAttachment attachment, CancellationToken ct = default);
    Task<MediaAttachment?> GetAttachmentAsync(Guid id, CancellationToken ct = default);
    Task<bool> IsAttachmentInMessageAsync(Guid roomId, Guid attachmentId, CancellationToken ct = default);
    Task<ChatMessage?> GetMessageByClientIdAsync(Guid roomId, Guid senderId, Guid clientId, CancellationToken ct = default);
    Task<ChatRoom?> GetRoomByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<ChatRoom?> GetRoomByIdAsync(Guid roomId, CancellationToken cancellationToken = default);
    Task AddRoomAsync(ChatRoom room, CancellationToken cancellationToken = default);
    Task AddMessageAsync(ChatMessage message, CancellationToken cancellationToken = default);
    Task<List<ChatMessage>> GetMessagesPagedAsync(Guid roomId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> GetMessageCountAsync(Guid roomId, CancellationToken cancellationToken = default);
    Task<List<ChatMessage>> GetImagesPagedAsync(Guid roomId, int page, int pageSize, CancellationToken ct);
    Task<int> GetImageCountAsync(Guid roomId, CancellationToken ct);
}
