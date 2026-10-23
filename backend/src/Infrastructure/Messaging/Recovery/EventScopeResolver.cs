using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.Messaging.Recovery;

public static class EventScopeResolver
{
    public static string Identity(string group, string topic, string key) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new[] {group, topic, key}))));

    public static async Task<Guid?> ResolveAsync(AppDbContext db, string topic, string payload, CancellationToken ct)
    {
        try
        {
            using var doc = JsonDocument.Parse(payload);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;
            Guid Read(string name) => root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String && value.TryGetGuid(out var id) ? id : Guid.Empty;
            var claimed = Read("HouseId");
            if (claimed == Guid.Empty && topic != KafkaTopics.BOUNTY_ACCEPTED) return null;
            Guid? actual;
            switch (topic)
            {
                case KafkaTopics.CHAT_MESSAGE_CREATED:
                    var messageId = Read("MessageId");
                    actual = await db.ChatMessages.Where(m => m.Id == messageId).Select(m => (Guid?)m.Room.HouseId).SingleOrDefaultAsync(ct);
                    break;
                case KafkaTopics.CHORE_COMPLETED:
                case KafkaTopics.CHORE_OVERDUE:
                case KafkaTopics.DEADLINE_REMINDER:
                    var occurrenceId = Read(topic == KafkaTopics.DEADLINE_REMINDER ? "ChoreOccurrenceId" : "OccurrenceId");
                    actual = await db.ChoreOccurrences.Where(o => o.Id == occurrenceId).Select(o => (Guid?)o.Chore.HouseId).SingleOrDefaultAsync(ct);
                    break;
                case KafkaTopics.BOUNTY_CREATED:
                case KafkaTopics.BOUNTY_ACCEPTED:
                case KafkaTopics.BOUNTY_EXPIRED:
                    var bountyId = Read("BountyId");
                    var bounty = await db.ChoreBounties.Where(b => b.Id == bountyId).Select(b => new {HouseId = b.ChoreOccurrence.Chore.HouseId, b.ChoreOccurrenceId}).SingleOrDefaultAsync(ct);
                    if (topic == KafkaTopics.BOUNTY_EXPIRED && bounty?.ChoreOccurrenceId != Read("OccurrenceId")) return null;
                    actual = bounty?.HouseId;
                    break;
                case KafkaTopics.SEASON_ENDED:
                    var seasonId = Read("SeasonId");
                    actual = await db.Seasons.Where(s => s.Id == seasonId).Select(s => (Guid?)s.HouseId).SingleOrDefaultAsync(ct);
                    break;
                default: return null;
            }
            return topic == KafkaTopics.BOUNTY_ACCEPTED && claimed == Guid.Empty ? actual : actual == claimed ? actual : null;
        }
        catch (JsonException) { return null; }
    }
}
