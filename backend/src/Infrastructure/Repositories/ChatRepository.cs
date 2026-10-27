using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class ChatRepository : IChatRepository
{
    public Task<List<ChatMessage>> GetImagesPagedAsync(Guid roomId,int page,int pageSize,CancellationToken ct)
        => _context.ChatMessages.Include(m=>m.Sender)
            .Where(m=>m.RoomId==roomId && m.MessageType==ChoreWars.Domain.Common.Constants.ChatConstants.ImageMessageType && m.AttachmentId!=null)
            .OrderByDescending(m=>m.CreatedAt).ThenByDescending(m=>m.Id).Skip((page-1)*pageSize).Take(pageSize).ToListAsync(ct);
    public Task<int> GetImageCountAsync(Guid roomId,CancellationToken ct)
        => _context.ChatMessages.CountAsync(m=>m.RoomId==roomId && m.MessageType==ChoreWars.Domain.Common.Constants.ChatConstants.ImageMessageType && m.AttachmentId!=null,ct);
    private readonly AppDbContext _context;

    public ChatRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task AddAttachmentAsync(MediaAttachment attachment, CancellationToken ct = default) => await _context.MediaAttachments.AddAsync(attachment, ct);
    public Task<MediaAttachment?> GetAttachmentAsync(Guid id, CancellationToken ct = default) => _context.MediaAttachments.FirstOrDefaultAsync(x => x.Id == id, ct);
    public Task<ChatMessage?> GetMessageByClientIdAsync(Guid roomId, Guid senderId, Guid clientId, CancellationToken ct = default)
        => _context.ChatMessages.Include(x => x.Sender).FirstOrDefaultAsync(x => x.RoomId == roomId && x.SenderId == senderId && x.ClientMessageId == clientId, ct);
    public async Task<ChatRoom?> GetRoomByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.ChatRooms
            .FirstOrDefaultAsync(r => r.HouseId == houseId, cancellationToken);
    }

    public async Task<ChatRoom?> GetRoomByIdAsync(Guid roomId, CancellationToken cancellationToken = default)
    {
        return await _context.ChatRooms
            .FirstOrDefaultAsync(r => r.Id == roomId, cancellationToken);
    }

    public async Task AddRoomAsync(ChatRoom room, CancellationToken cancellationToken = default)
    {
        await _context.ChatRooms.AddAsync(room, cancellationToken);
    }

    public async Task AddMessageAsync(ChatMessage message, CancellationToken cancellationToken = default)
    {
        await _context.ChatMessages.AddAsync(message, cancellationToken);
    }

    public async Task<List<ChatMessage>> GetMessagesPagedAsync(Guid roomId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .Include(m => m.Sender)
            .Where(m => m.RoomId == roomId)
            .OrderByDescending(m => m.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> GetMessageCountAsync(Guid roomId, CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .Where(m => m.RoomId == roomId)
            .CountAsync(cancellationToken);
    }
}
