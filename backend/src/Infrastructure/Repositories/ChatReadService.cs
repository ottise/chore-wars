using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Infrastructure.Repositories;

public sealed class ChatReadService(AppDbContext db, IHouseMutationCoordinator mutations, INotificationRealtimePublisher realtime) : IChatReadService
{
    private async Task<HouseMember> Member(Guid house, Guid actor, CancellationToken ct) =>
        await db.HouseMembers.SingleOrDefaultAsync(m => m.HouseId == house && m.UserId == actor && m.Status == HouseMemberStatus.ACTIVE, ct)
        ?? throw new ForbiddenException();
    public async Task<int> UnreadAsync(Guid house, Guid actor, CancellationToken ct)
    {
        var member = await Member(house, actor, ct);
        var at = member.ChatReadAt ?? member.JoinedAt;
        var last = member.ChatReadMessageId ?? Guid.Empty;
        return await db.ChatMessages.CountAsync(m => m.Room.HouseId == house && m.SenderId != actor &&
            (m.CreatedAt > at || m.CreatedAt == at && m.Id.CompareTo(last) > 0), ct);
    }
    public async Task ReadAsync(Guid house, Guid actor, Guid messageId, CancellationToken ct)
    {
        await mutations.RunAsync(house, async () =>
        {
            var member = await Member(house, actor, ct);
            var message = await db.ChatMessages.SingleOrDefaultAsync(m => m.Id == messageId && m.Room.HouseId == house, ct) ?? throw new NotFoundException("Message not found in this household.");
            var at = member.ChatReadAt ?? member.JoinedAt;
            var last = member.ChatReadMessageId ?? Guid.Empty;
            // PostgreSQL uuid ordering matches canonical hexadecimal string ordering.
            if (message.CreatedAt > at || message.CreatedAt == at && string.CompareOrdinal(message.Id.ToString("N"), last.ToString("N")) > 0)
            {
                member.ChatReadAt = message.CreatedAt; member.ChatReadMessageId = message.Id;
                await db.SaveChangesAsync(ct);
            }
        }, ct);
        try { await realtime.ChatUnreadChangedAsync(actor, house, ct); } catch { /* The persisted cursor remains authoritative. */ }
    }
}
