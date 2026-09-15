using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Confluent.Kafka;
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

    protected KafkaConsumerBase(
        string topic,
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger logger)
    {
        _topic = topic;
        _options = options.Value;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        return Task.Run(() => StartConsumerLoop(stoppingToken), stoppingToken);
    }

    private async Task StartConsumerLoop(CancellationToken cancellationToken)
    {
        var config = new ConsumerConfig
        {
            BootstrapServers = _options.BootstrapServers,
            GroupId = _options.ConsumerGroupId,
            AutoOffsetReset = AutoOffsetReset.Earliest,
            EnableAutoCommit = false
        };

        using var consumer = new ConsumerBuilder<string, string>(config).Build();
        consumer.Subscribe(_topic);

        _logger.LogInformation($"Started consuming topic {_topic}");

        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    var consumeResult = consumer.Consume(cancellationToken);
                    if (consumeResult?.Message == null) continue;

                    var @event = JsonSerializer.Deserialize<TEvent>(consumeResult.Message.Value);
                    if (@event != null)
                    {
                        using var scope = _scopeFactory.CreateScope();
                        await ProcessEventAsync(@event, scope.ServiceProvider, cancellationToken);
                        consumer.Commit(consumeResult);
                    }
                }
                catch (ConsumeException e)
                {
                    _logger.LogError($"Consume error: {e.Error.Reason}");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error processing message from topic {_topic}");
                }
            }
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation($"Consumer for topic {_topic} cancelled.");
        }
        finally
        {
            consumer.Close();
        }
    }

    protected abstract Task ProcessEventAsync(TEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken);
}
