using System.Text.Json;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Recovery;
using Confluent.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public abstract class KafkaConsumerBase<TEvent> : BackgroundService
{
    private readonly string _topic;
    private readonly KafkaOptions _options;
    protected readonly IServiceScopeFactory _scopeFactory;
    protected readonly ILogger _logger;

    protected KafkaConsumerBase(string topic, IOptions<KafkaOptions> options, IServiceScopeFactory scopeFactory, ILogger logger)
    { _topic = topic; _options = options.Value; _scopeFactory = scopeFactory; _logger = logger; }

    protected override Task ExecuteAsync(CancellationToken stoppingToken) => Task.Factory.StartNew(
        () => ConsumeLoop(stoppingToken), stoppingToken, TaskCreationOptions.LongRunning, TaskScheduler.Default).Unwrap();

    private async Task ConsumeLoop(CancellationToken ct)
    {
        using var consumer = new ConsumerBuilder<string,string>(new ConsumerConfig(_options.ConnectionConfig()) {
            GroupId = _options.ConsumerGroupId,
            AutoOffsetReset = AutoOffsetReset.Earliest, EnableAutoCommit = false, EnableAutoOffsetStore = false,
            SessionTimeoutMs = _options.SessionTimeoutMs, HeartbeatIntervalMs = Math.Max(1000,_options.SessionTimeoutMs/3)
        }).Build();
        consumer.Subscribe(_options.TopicPrefix + _topic);
        try
        {
            while (!ct.IsCancellationRequested)
            {
                ConsumeResult<string,string>? current = null;
                try
                {
                    current = consumer.Consume(ct);
                    if (current?.Message == null) continue;
                    var key = current.Message.Key ?? current.TopicPartitionOffset.ToString();
                    var payload = current.Message.Value ?? "null";
                    Exception? failure = null;
                    for (var attempt = 0; attempt < 4; attempt++)
                    {
                        try { await ProcessOnce(key,payload,ct); failure = null; break; }
                        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
                        catch (Exception error)
                        {
                            failure = error;
                            _logger.LogWarning(error,"Event failed on {Topic}, attempt {Attempt}",_topic,attempt+1);
                            if (attempt < 3) await Task.Delay(TimeSpan.FromSeconds(1 << (attempt+1)),ct);
                        }
                    }
                    if (failure != null)
                    {
                        await using var scope = _scopeFactory.CreateAsyncScope();
                        // Only advance the offset once the complete failed payload is durably isolated.
                        await FailedEventStore.CaptureAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(),
                            _options.ConsumerGroupId,_topic,key,payload,current.Partition.Value,current.Offset.Value,failure,ct);
                    }
                    consumer.Commit(current);
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested) { break; }
                catch (Exception error)
                {
                    _logger.LogError(error,"Consumer cannot complete processing/quarantine for {Topic}; retrying without advancing offset",_topic);
                    if (current?.Message != null) consumer.Seek(current.TopicPartitionOffset);
                    await Task.Delay(TimeSpan.FromSeconds(2),ct);
                }
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { }
        finally { consumer.Close(); }
    }

    private async Task ProcessOnce(string key, string payload, CancellationToken ct)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var services = scope.ServiceProvider;
        var db = services.GetRequiredService<AppDbContext>();
        var uow = services.GetRequiredService<IUnitOfWork>();
        var afterCommit = services.GetRequiredService<IAfterCommitActions>();
        await uow.BeginTransactionAsync(ct);
        try
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({_topic+":"+key},0))",ct);
            if (!await db.ProcessedMessages.AnyAsync(x => x.Consumer == _topic && x.Id == key,ct))
            {
                var message = JsonSerializer.Deserialize<TEvent>(payload);
                if (message == null) throw new JsonException("Event payload cannot be null.");
                if (typeof(TEvent).GetProperties().Any(p => p.PropertyType == typeof(Guid) && (Guid)p.GetValue(message)! == Guid.Empty))
                    throw new JsonException("Required event identifiers cannot be empty.");
                if (await EventScopeResolver.ResolveAsync(db,_topic,payload,ct) == null)
                    throw new InvalidDataException("Event household cannot be verified from its resource.");
                await ProcessEventAsync(message,services,ct);
                db.ProcessedMessages.Add(new ProcessedMessage { Consumer = _topic, Id = key, ProcessedAt = DateTime.UtcNow });
            }
            await FailedEventStore.ResolveAsync(db,_options.ConsumerGroupId,_topic,key,ct);
            await uow.SaveChangesAsync(ct);
            await services.GetRequiredService<ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe>().HitAsync("consumer.before-commit",ct);
            await uow.CommitTransactionAsync(ct);
            await services.GetRequiredService<ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe>().HitAsync("consumer.after-commit",ct);
            await afterCommit.FlushAsync();
        }
        catch { afterCommit.Clear(); await uow.RollbackTransactionAsync(ct); throw; }
    }

    protected abstract Task ProcessEventAsync(TEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken);
}
