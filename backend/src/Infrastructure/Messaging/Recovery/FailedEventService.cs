using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Recovery;

public sealed class FailedEventService(AppDbContext db, IHouseMutationCoordinator mutations, IOptions<KafkaOptions> kafka) : IFailedEventService
{
    private async Task Owner(Guid houseId, Guid userId, CancellationToken ct)
    {
        if (!await db.HouseMembers.AnyAsync(m => m.HouseId == houseId && m.UserId == userId && m.Status == HouseMemberStatus.ACTIVE && m.Role == HouseRole.OWNER,ct))
            throw new ForbiddenException("Only the active household owner can manage failed events.");
    }
    public async Task<FailedEventPage> ListAsync(Guid houseId, Guid userId, string? status, int page, CancellationToken ct)
    {
        await Owner(houseId,userId,ct);
        if (page < 1 || page > 100000 || (status != null && status is not ("FAILED" or "REPLAY_REQUESTED" or "RESOLVED")))
            throw new DomainException("Invalid page or event status.");
        var query = db.FailedEvents.AsNoTracking().Where(e => e.HouseId == houseId);
        if (status != null) query = query.Where(e => e.Status == status);
        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(e => e.LastFailedAt).ThenBy(e => e.Id).Skip((page-1)*20).Take(20)
            .Select(e => new FailedEventItem(e.Id,e.Topic,e.Status,e.ErrorCode,e.FailureCount,e.FirstFailedAt,e.LastFailedAt,e.ResolvedAt,db.FailedEventReplays.Count(r => r.FailedEventId == e.Id))).ToListAsync(ct);
        return new(items,total,page,20);
    }
    public Task ReplayAsync(Guid houseId, Guid failedEventId, Guid userId, CancellationToken ct) => mutations.RunAsync(houseId,async () =>
    {
        await Owner(houseId,userId,ct);
        // Lock the event as well: consumers use the same lock while quarantining/resolving.
        if (await db.Houses.AnyAsync(h => h.Id == houseId && h.IsArchived,ct))
            throw new ConflictException("Archived households are read-only.");
        var identity = await db.FailedEvents.Where(e => e.Id == failedEventId && e.HouseId == houseId).Select(e => e.Identity).SingleOrDefaultAsync(ct)
            ?? throw new NotFoundException("Failed event not found in this household.");
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({"failed:"+identity},0))",ct);
        var item = await db.FailedEvents.SingleAsync(e => e.Id == failedEventId && e.HouseId == houseId,ct);
        if (item.Status == "REPLAY_REQUESTED") return; // Request retry must not enqueue twice.
        if (item.Status != "FAILED") throw new ConflictException("This event has already been resolved.");
        if (item.ConsumerGroup != kafka.Value.ConsumerGroupId) throw new ConflictException("This event belongs to a different processing configuration.");
        if (await EventScopeResolver.ResolveAsync(db,item.Topic,item.Payload,ct) != houseId)
            throw new ConflictException("The event can no longer be verified as belonging to this household.");
        var now = DateTime.UtcNow;
        var outbox = new OutboxMessage { Id = Guid.NewGuid(), Topic = item.Topic, MessageKey = item.EventKey, Payload = item.Payload, CreatedAt = now };
        db.OutboxMessages.Add(outbox);
        db.FailedEventReplays.Add(new FailedEventReplay { Id = Guid.NewGuid(), FailedEventId = item.Id, RequestedByUserId = userId, OutboxId = outbox.Id, RequestedAt = now });
        item.Status = "REPLAY_REQUESTED";
    },ct);
}
