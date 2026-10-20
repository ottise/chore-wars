using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Chat;
namespace ChoreWars.Application.Interfaces.Services;
public interface IMediaService {
    Task<MediaAttachment> UploadAsync(Guid roomId, Guid userId, byte[] data, CancellationToken ct);
    Task<(MediaAttachment Metadata, Stream Stream)> DownloadAsync(Guid id, Guid userId, CancellationToken ct);
    Task<ChatMessageResponse> SendAsync(Guid roomId, Guid attachmentId, Guid clientId, Guid userId, CancellationToken ct);
}
