using System.Text.Json;
using ChoreWars.Application.Interfaces;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
namespace ChoreWars.Infrastructure.Messaging;
public sealed class OutboxEventPublisher(AppDbContext db) : IEventPublisher {
    public async Task PublishAsync<T>(T message, CancellationToken cancellationToken = default) {
        if (!KafkaTopics.EventTopicMap.TryGetValue(typeof(T), out var topic)) throw new InvalidOperationException("No event topic registered.");
        await db.OutboxMessages.AddAsync(new OutboxMessage { Id = Guid.NewGuid(), Topic = topic, Payload = JsonSerializer.Serialize(message), CreatedAt = DateTime.UtcNow }, cancellationToken);
        // Save inside the caller's transaction; the dispatcher sees committed rows only.
        await db.SaveChangesAsync(cancellationToken);
    }
}
