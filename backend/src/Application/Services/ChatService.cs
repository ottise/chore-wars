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

namespace ChoreWars.Application.Services;

public class ChatService : IChatService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly IUnitOfWork _unitOfWork;
    private readonly TimeProvider _clock;

    public ChatService(IUnitOfWork unitOfWork,IHouseMutationCoordinator? mutations=null,TimeProvider? clock=null)
    {
        _mutations=mutations;
        _unitOfWork = unitOfWork;
        _clock=clock ?? TimeProvider.System;
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
    private async Task<ChatMessageResponse> CreateMessageCoreAsync(Guid roomId, Guid userId, string content, CancellationToken cancellationToken)
    {
        if (content?.Length > 4000) throw new DomainException("Messages cannot exceed 4000 characters.");
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

        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            RoomId = roomId,
            SenderId = userId,
            Content = content,
            CreatedAt = _clock.GetUtcNow().UtcDateTime
        };

        await _unitOfWork.Chats.AddMessageAsync(message, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new ChatMessageResponse
        {
            Id = message.Id,
            RoomId = message.RoomId,
            SenderId = message.SenderId,
            SenderName = user.DisplayName,
            SenderAvatar = user.AvatarUrl,
            Content = message.Content,
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

    private async Task ValidateHouseMembershipAsync(Guid houseId, Guid userId, CancellationToken cancellationToken)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
        {
            throw new ForbiddenException("You are not a member of this house.");
        }
    }
}
