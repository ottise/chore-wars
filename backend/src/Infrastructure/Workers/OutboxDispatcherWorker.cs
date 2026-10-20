using ChoreWars.Infrastructure.Data;
using Confluent.Kafka;
using ChoreWars.Infrastructure.Messaging.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
namespace ChoreWars.Infrastructure.Workers;
public sealed class OutboxDispatcherWorker(IServiceScopeFactory scopes, IOptions<KafkaOptions> options, ILogger<OutboxDispatcherWorker> logger) : BackgroundService {
    protected override async Task ExecuteAsync(CancellationToken ct) {
        using var producer = new ProducerBuilder<string, string>(new ProducerConfig { BootstrapServers = options.Value.BootstrapServers, EnableIdempotence = true, MessageTimeoutMs = 10000 }).Build();
        while (!ct.IsCancellationRequested) {
            try {
                using var scope = scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                await using var tx = await db.Database.BeginTransactionAsync(ct);
                var messages = await db.OutboxMessages.FromSqlRaw("SELECT * FROM \"OutboxMessages\" WHERE \"PublishedAt\" IS NULL ORDER BY \"CreatedAt\" LIMIT 50 FOR UPDATE SKIP LOCKED").ToListAsync(ct);
                foreach (var message in messages) {
                    await producer.ProduceAsync(options.Value.TopicPrefix + message.Topic, new Message<string, string> { Key = message.MessageKey ?? message.Id.ToString(), Value = message.Payload }, ct);
                    await scope.ServiceProvider.GetRequiredService<ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe>().HitAsync("outbox.after-publish",ct);
                    message.PublishedAt = DateTime.UtcNow;
                }
                await db.SaveChangesAsync(ct);
                await scope.ServiceProvider.GetRequiredService<ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe>().HitAsync("outbox.before-commit",ct);
                await tx.CommitAsync(ct);
            } catch (OperationCanceledException) when (ct.IsCancellationRequested) { break; }
            catch (Exception ex) {
                logger.LogError(ex, "Outbox dispatch failed; unpublished events will retry.");
                using var failureScope = scopes.CreateScope();
                await failureScope.ServiceProvider.GetRequiredService<ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe>().HitAsync("outbox.dispatch-failed",ct);
            }
            try { await Task.Delay(TimeSpan.FromSeconds(2), ct); } catch (OperationCanceledException) when (ct.IsCancellationRequested) { break; }
        }
    }
}
