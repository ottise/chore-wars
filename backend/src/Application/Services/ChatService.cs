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
    private readonly IUnitOfWork _unitOfWork;

    public ChatService(IUnitOfWork unitOfWork)
    {
        _unitOfWork = unitOfWork;
    }

    public async Task<ChatRoomResponse> GetHouseRoomAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
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
                CreatedAt = DateTime.UtcNow
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

        var totalCount = await _unitOfWork.Chats.GetMessageCountAsync(roomId, cancellationToken);
        var messages = await _unitOfWork.Chats.GetMessagesPagedAsync(roomId, page, pageSize, cancellationToken);

        var items = messages.Select(m => new ChatMessageResponse
        {
            Id = m.Id,
            RoomId = m.RoomId,
            SenderId = m.SenderId,
            SenderName = m.Sender?.DisplayName ?? "Unknown",
            SenderAvatar = m.Sender?.AvatarUrl,
            Content = m.Content,
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
        if (string.IsNullOrWhiteSpace(content))
        {
            throw new DomainException("Message content cannot be empty.");
        }

        var room = await _unitOfWork.Chats.GetRoomByIdAsync(roomId, cancellationToken)
            ?? throw new NotFoundException($"ChatRoom {roomId} not found");

        await ValidateHouseMembershipAsync(room.HouseId, userId, cancellationToken);

        var user = await _unitOfWork.Users.GetByIdAsync(userId, cancellationToken)
            ?? throw new NotFoundException($"User {userId} not found");

        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            RoomId = roomId,
            SenderId = userId,
            Content = content,
            CreatedAt = DateTime.UtcNow
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

    private async Task ValidateHouseMembershipAsync(Guid houseId, Guid userId, CancellationToken cancellationToken)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
        {
            throw new ForbiddenException("You are not a member of this house.");
        }
    }
}
