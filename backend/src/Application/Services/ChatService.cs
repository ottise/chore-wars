using ChoreWars.Domain.Enums;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Chat;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Events;
using ChoreWars.Domain.Common.Constants;

namespace ChoreWars.Application.Services;

public class ChatService : IChatService
{
    private const string TextMessageType = "TEXT";
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly IUnitOfWork _unitOfWork;
    private readonly TimeProvider _clock;
    private readonly IEventPublisher? _events;

    public ChatService(IUnitOfWork unitOfWork,IHouseMutationCoordinator? mutations=null,TimeProvider? clock=null,IEventPublisher? events=null)
    {
        _mutations=mutations;
        _unitOfWork = unitOfWork;
        _clock=clock ?? TimeProvider.System;
        _events=events;
    }

    public async Task<bool> GetNotificationsEnabledAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await ValidateHouseMembershipAsync(houseId, userId, cancellationToken);
        return !member.ChatNotificationsMuted;
    }

    public async Task SetNotificationsEnabledAsync(Guid houseId, Guid userId, bool enabled, CancellationToken cancellationToken = default)
    {
        async Task Update()
        {
            var member = await ValidateHouseMembershipAsync(houseId, userId, cancellationToken);
            member.ChatNotificationsMuted = !enabled;
            _unitOfWork.HouseMembers.Update(member);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }
        if (_mutations != null) await _mutations.RunAsync(houseId, Update, cancellationToken);
        else await Update();
    }

    public async Task<ChatRoomResponse> GetHouseRoomAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        return _mutations!=null?await _mutations.RunAsync(houseId,()=>GetHouseRoomCoreAsync(houseId,userId,cancellationToken),cancellationToken):await GetHouseRoomCoreAsync(houseId,userId,cancellationToken);
    }
    private async Task<ChatRoomResponse> GetHouseRoomCoreAsync(Guid houseId, Guid userId, CancellationToken cancellationToken)
    {
        await ValidateHouseMembershipAsync(houseId, userId, cancellationToken);

        var room = await _unitOfWork.Chats.GetRoomByHouseIdAsync(houseId, cancellationToken);
        if (room == null)
        {
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId, cancellationToken)
                ?? throw new NotFoundException($"House {houseId} not found");

            room = new ChatRoom
            {
                Id = Guid.NewGuid(),
                HouseId = houseId,
                Name = $"{house.Name} Chat",
                CreatedAt = _clock.GetUtcNow().UtcDateTime
            };
            await _unitOfWork.Chats.AddRoomAsync(room, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }

        return new ChatRoomResponse
        {
            Id = room.Id,
            HouseId = room.HouseId,
            Name = room.Name
        };
    }

    public async Task<PagedResult<ChatMessageResponse>> GetMessagesAsync(Guid roomId, Guid userId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var room = await _unitOfWork.Chats.GetRoomByIdAsync(roomId, cancellationToken)
            ?? throw new NotFoundException($"ChatRoom {roomId} not found");

        await ValidateHouseMembershipAsync(room.HouseId, userId, cancellationToken);

        if (page < 1 || pageSize < 1 || pageSize > 100) throw new DomainException("Invalid pagination.");
        var totalCount = await _unitOfWork.Chats.GetMessageCountAsync(roomId, cancellationToken);
        var messages = await _unitOfWork.Chats.GetMessagesPagedAsync(roomId, page, pageSize, cancellationToken);

        var items = messages.Select(m => new ChatMessageResponse
        {
            Id = m.Id,
            RoomId = m.RoomId,
            SenderId = m.SenderId,
            SenderName = m.Sender?.DisplayName ?? "Unknown",
            SenderAvatar = m.Sender?.AvatarUrl,
            Content = m.Content, MessageType = m.MessageType, AttachmentId = m.AttachmentId, ClientMessageId = m.ClientMessageId,
            CreatedAt = m.CreatedAt,
            EditedAt = m.EditedAt
        }).ToList();

        return new PagedResult<ChatMessageResponse>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalCount = totalCount
        };
    }

    public async Task<ChatMessageResponse> CreateMessageAsync(Guid roomId, Guid userId, string content, CancellationToken cancellationToken = default)
    {
        var room=await _unitOfWork.Chats.GetRoomByIdAsync(roomId,cancellationToken)??throw new NotFoundException("Room not found.");
        return _mutations!=null?await _mutations.RunAsync(room.HouseId,()=>CreateMessageCoreAsync(roomId,userId,content,cancellationToken),cancellationToken):await CreateMessageCoreAsync(roomId,userId,content,cancellationToken);
    }
    public async Task<ChatMessageResponse> CreateTextMessageAsync(Guid roomId, Guid userId, string content, Guid clientMessageId, CancellationToken cancellationToken = default)
    {
        if (clientMessageId == Guid.Empty) throw new DomainException("A client message ID is required.");
        var room = await _unitOfWork.Chats.GetRoomByIdAsync(roomId, cancellationToken) ?? throw new NotFoundException("Room not found.");
        return _mutations != null
            ? await _mutations.RunAsync(room.HouseId, () => CreateMessageCoreAsync(roomId, userId, content, cancellationToken, clientMessageId), cancellationToken)
            : await CreateMessageCoreAsync(roomId, userId, content, cancellationToken, clientMessageId);
    }
    private async Task<ChatMessageResponse> CreateMessageCoreAsync(Guid roomId, Guid userId, string content, CancellationToken cancellationToken, Guid? clientMessageId = null)
    {
        if (content?.Length > ChatConstants.MaxMessageLength) throw new DomainException($"Messages cannot exceed {ChatConstants.MaxMessageLength} characters.");
        if (string.IsNullOrWhiteSpace(content))
        {
            throw new DomainException("Message content cannot be empty.");
        }

        var room = await _unitOfWork.Chats.GetRoomByIdAsync(roomId, cancellationToken)
            ?? throw new NotFoundException($"ChatRoom {roomId} not found");

        await ValidateHouseMembershipAsync(room.HouseId, userId, cancellationToken);
        var houseContext = await _unitOfWork.Houses.GetByIdAsync(room.HouseId,cancellationToken);
        if (houseContext?.IsArchived == true) throw new ConflictException("Archived households are read-only.");

        var user = await _unitOfWork.Users.GetByIdAsync(userId, cancellationToken)
            ?? throw new NotFoundException($"User {userId} not found");

        if (clientMessageId.HasValue) {
            var prior = await _unitOfWork.Chats.GetMessageByClientIdAsync(roomId, userId, clientMessageId.Value, cancellationToken);
            if (prior != null) {
                if (prior.Content != content || prior.MessageType != TextMessageType) throw new ConflictException("Client message ID was used for different content.");
                return new ChatMessageResponse { Id = prior.Id, RoomId = prior.RoomId, SenderId = prior.SenderId, SenderName = user.DisplayName, SenderAvatar = user.AvatarUrl, Content = prior.Content, CreatedAt = prior.CreatedAt, ClientMessageId = prior.ClientMessageId };
            }
        }

        var activeMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(room.HouseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE).Select(m => m.UserId).ToHashSet();
        var mentions = ChatMentions.Resolve(content, activeMembers).Where(id => id != userId).ToArray();

        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            RoomId = roomId,
            SenderId = userId,
            Content = content,
            ClientMessageId = clientMessageId,
            CreatedAt = _clock.GetUtcNow().UtcDateTime
        };

        await _unitOfWork.Chats.AddMessageAsync(message, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        if (_events != null)
            await _events.PublishAsync(new ChatMessageCreatedEvent(message.Id, room.HouseId,
                activeMembers.Where(id => id != userId).ToArray(), mentions), cancellationToken);

        return new ChatMessageResponse
        {
            Id = message.Id,
            RoomId = message.RoomId,
            SenderId = message.SenderId,
            SenderName = user.DisplayName,
            SenderAvatar = user.AvatarUrl,
            Content = message.Content,
            ClientMessageId = message.ClientMessageId,
            CreatedAt = message.CreatedAt,
            EditedAt = message.EditedAt
        };
    }

    public async Task EnsureRoomAccessAsync(Guid roomId, Guid userId, CancellationToken cancellationToken = default)
    {
        var room = await _unitOfWork.Chats.GetRoomByIdAsync(roomId, cancellationToken)
            ?? throw new NotFoundException($"ChatRoom {roomId} not found");
        await ValidateHouseMembershipAsync(room.HouseId, userId, cancellationToken);
    }

    private async Task<HouseMember> ValidateHouseMembershipAsync(Guid houseId, Guid userId, CancellationToken cancellationToken)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
        {
            throw new ForbiddenException("You are not a member of this house.");
        }
        return member;
    }
}
