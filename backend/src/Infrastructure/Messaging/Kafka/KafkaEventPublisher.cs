using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System;
using Confluent.Kafka;
using ChoreWars.Application.Interfaces;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka;

public class KafkaEventPublisher : IEventPublisher
{
    private readonly IProducer<string, string> _producer;

    public KafkaEventPublisher(IOptions<KafkaOptions> options)
    {
        var config = new ProducerConfig
        {
            BootstrapServers = options.Value.BootstrapServers
        };
        _producer = new ProducerBuilder<string, string>(config).Build();
    }

    public async Task PublishAsync<T>(T @event, CancellationToken cancellationToken = default)
    {
        if (!KafkaTopics.EventTopicMap.TryGetValue(typeof(T), out var topic))
        {
            throw new InvalidOperationException($"No topic mapped for event type {typeof(T).Name}");
        }
        var message = new Message<string, string>
        {
            Key = Guid.NewGuid().ToString(),
            Value = JsonSerializer.Serialize(@event)
        };

        await _producer.ProduceAsync(topic, message, cancellationToken);
    }
}
