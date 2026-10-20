using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.Messaging.Recovery;

public static class FailedEventStore
{
    public static async Task CaptureAsync(AppDbContext db, string group, string topic, string key, string payload,
        int partition, long offset, Exception error, CancellationToken ct)
    {
        var identity = EventScopeResolver.Identity(group,topic,key);
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({"failed:"+identity},0))",ct);
        var item = await db.FailedEvents.SingleOrDefaultAsync(e => e.Identity == identity,ct);
        var now = DateTime.UtcNow;
        if (item == null)
        {
            item = new FailedEvent { Id = Guid.NewGuid(), Identity = identity, ConsumerGroup = group, Topic = topic,
                EventKey = key, Payload = payload, Partition = partition, Offset = offset, FirstFailedAt = now,
                HouseId = await EventScopeResolver.ResolveAsync(db,topic,payload,ct) };
            db.FailedEvents.Add(item);
        }
        // Preserve the original payload; a reused key must not replace replay content.
        if (item.Payload != payload) throw new InvalidOperationException("A failed event key was reused with different content.");
        item.ErrorCode = error.GetType().Name;
        item.Status = "FAILED";
        item.FailureCount++;
        item.LastFailedAt = now;
        item.ResolvedAt = null;
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
    }

    // Called inside the consumer's business transaction.
    public static async Task ResolveAsync(AppDbContext db, string group, string topic, string key, CancellationToken ct)
    {
        var identity = EventScopeResolver.Identity(group,topic,key);
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({"failed:"+identity},0))",ct);
        var item = await db.FailedEvents.SingleOrDefaultAsync(e => e.Identity == identity,ct);
        if (item != null) { item.Status = "RESOLVED"; item.ResolvedAt = DateTime.UtcNow; }
    }
}
