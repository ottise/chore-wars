using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.DTOs.Chat;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Events;
using ChoreWars.Domain.Enums;
namespace ChoreWars.Application.Services;
public sealed class MediaService(IUnitOfWork uow, IChatService chat, IMediaStorage storage, IHouseMutationCoordinator mutations, IHouseAccessService access, TimeProvider? clock = null, IEventPublisher? events = null) : IMediaService {
    private TimeProvider Clock => clock ?? TimeProvider.System;
    public async Task<MediaAttachment> UploadAsync(Guid roomId, Guid userId, byte[] data, CancellationToken ct) {
        await chat.EnsureRoomAccessAsync(roomId,userId,ct);
        var room = await uow.Chats.GetRoomByIdAsync(roomId,ct) ?? throw new NotFoundException("Room not found.");
        await access.EnsureWritableAsync(room.HouseId,ct);
        var info = MediaInspector.Inspect(data);
        var media = new MediaAttachment { Id = Guid.NewGuid(), RoomId = roomId, OwnerId = userId, ContentType = info.Mime, Type = info.Type, DurationSeconds = info.Duration, Size = data.Length, CreatedAt = Clock.GetUtcNow().UtcDateTime };
        media.StorageKey = media.Id.ToString("N");
        await storage.WriteAsync(media.StorageKey,data,ct);
        try { await uow.Chats.AddAttachmentAsync(media,ct); await uow.SaveChangesAsync(ct); }
        catch { await storage.DeleteAsync(media.StorageKey,CancellationToken.None); throw; }
        return media;
    }
    public async Task<(MediaAttachment Metadata, Stream Stream)> DownloadAsync(Guid id, Guid userId, CancellationToken ct) {
        var media = await uow.Chats.GetAttachmentAsync(id,ct) ?? throw new NotFoundException("Media not found.");
        await chat.EnsureRoomAccessAsync(media.RoomId,userId,ct);
        if (media.AttachedAt == null && media.OwnerId != userId
            && !await uow.Chats.IsAttachmentInMessageAsync(media.RoomId,media.Id,ct)) throw new ForbiddenException();
        return (media, await storage.ReadAsync(media.StorageKey,ct));
    }
    public async Task<ChatMessageResponse> SendAsync(Guid roomId, Guid attachmentId, Guid clientId, Guid userId, CancellationToken ct) {
        var room = await uow.Chats.GetRoomByIdAsync(roomId,ct) ?? throw new NotFoundException("Room not found.");
        return await mutations.RunAsync(room.HouseId, async () => {
            await chat.EnsureRoomAccessAsync(roomId,userId,ct);
            await access.EnsureWritableAsync(room.HouseId,ct);
            if (clientId == Guid.Empty) throw new DomainException("A client message ID is required.");
            var prior = await uow.Chats.GetMessageByClientIdAsync(roomId,userId,clientId,ct);
            if (prior != null) {
                if (prior.AttachmentId != attachmentId) throw new ConflictException("Client message ID was already used for different content.");
                return Map(prior,prior.Sender);
            }
            var media = await uow.Chats.GetAttachmentAsync(attachmentId,ct) ?? throw new NotFoundException("Media not found.");
            if (media.RoomId != roomId || media.OwnerId != userId) throw new ForbiddenException();
            if (media.AttachedAt.HasValue) throw new ConflictException("Media is already attached.");
            var user = await uow.Users.GetByIdAsync(userId,ct) ?? throw new NotFoundException("User not found.");
            media.AttachedAt = Clock.GetUtcNow().UtcDateTime;
            var message = new ChatMessage { Id = Guid.NewGuid(), RoomId = roomId, SenderId = userId, MessageType = media.Type, AttachmentId = media.Id, ClientMessageId = clientId, CreatedAt = Clock.GetUtcNow().UtcDateTime };
            await uow.Chats.AddMessageAsync(message,ct);
            await uow.SaveChangesAsync(ct);
            if (events != null) {
                var recipients = (await uow.HouseMembers.GetByHouseIdAsync(room.HouseId,ct))
                    .Where(m => m.Status == HouseMemberStatus.ACTIVE && m.UserId != userId).Select(m => m.UserId).ToArray();
                await events.PublishAsync(new ChatMessageCreatedEvent(message.Id,room.HouseId,recipients,[]),ct);
            }
            return Map(message,user);
        },ct);
    }
    private static ChatMessageResponse Map(ChatMessage m, User user) => new() { Id = m.Id, RoomId = m.RoomId, SenderId = m.SenderId, SenderName = user.DisplayName, SenderAvatar = user.AvatarUrl, Content = m.Content, MessageType = m.MessageType, AttachmentId = m.AttachmentId, ClientMessageId = m.ClientMessageId, CreatedAt = m.CreatedAt };
}
