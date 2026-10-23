using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using ChoreWars.Infrastructure.Messaging.Kafka.Consumers;
using ChoreWars.Infrastructure.Workers;
using Confluent.Kafka;
using Confluent.Kafka.Admin;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;

namespace IntegrationTests.Infrastructure;

[Collection("Kafka runtime")]
public sealed class ChatNotificationsKafkaTests
{
    [KafkaFact]
    public async Task OutboxToChatInboxIsIdempotentAndRechecksDepartedRecipients()
    {
        var group = "cw-chat-test-" + Guid.NewGuid().ToString("N");
        var options = new KafkaOptions { BootstrapServers = Environment.GetEnvironmentVariable("CHOREWARS_TEST_KAFKA")!, ConsumerGroupId = group, TopicPrefix = group + ".", SessionTimeoutMs = 6000 };
        var topic = options.TopicPrefix + KafkaTopics.CHAT_MESSAGE_CREATED;
        using var admin = new AdminClientBuilder(new AdminClientConfig { BootstrapServers = options.BootstrapServers }).Build();
        await admin.CreateTopicsAsync([new TopicSpecification { Name = topic, NumPartitions = 1, ReplicationFactor = 1 }]);
        var realtime = new Mock<INotificationRealtimePublisher>();
        realtime.Setup(s => s.PublishAsync(It.IsAny<NotificationResponse>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        await using var fixture = await PostgresFixture.CreateAsync(new() {
            ["Kafka:BootstrapServers"] = options.BootstrapServers, ["Kafka:ConsumerGroupId"] = group, ["Kafka:TopicPrefix"] = options.TopicPrefix
        }, services => services.AddSingleton(realtime.Object));
        var seed = await CoreConcurrencyTests.Seed(fixture);
        Guid roomId; Guid eventId; string payload;
        await using (var scope = fixture.Services.CreateAsyncScope()) {
            var chat = scope.ServiceProvider.GetRequiredService<IChatService>();
            roomId = (await chat.GetHouseRoomAsync(seed.HouseId, seed.Users[0])).Id;
            await chat.CreateMessageAsync(roomId, seed.Users[0], $"@{{{seed.Users[1]}}} tin nhắn riêng");
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var message = await db.OutboxMessages.SingleAsync(); eventId = message.Id; payload = message.Payload;
            (await db.HouseMembers.SingleAsync(m => m.UserId == seed.Users[2])).Status = HouseMemberStatus.LEFT;
            await db.SaveChangesAsync();
        }
        var scopes = fixture.Services.GetRequiredService<IServiceScopeFactory>();
        using var consumer = new ChatMessageCreatedConsumer(Options.Create(options), scopes, NullLogger<ChatMessageCreatedConsumer>.Instance);
        using var dispatcher = new OutboxDispatcherWorker(scopes, Options.Create(options), NullLogger<OutboxDispatcherWorker>.Instance);
        await consumer.StartAsync(default); await dispatcher.StartAsync(default);
        try {
            await Until(async () => await Processed(fixture) == 1);
            using var producer = new ProducerBuilder<string, string>(new ProducerConfig { BootstrapServers = options.BootstrapServers, MessageTimeoutMs = 10000 }).Build();
            await producer.ProduceAsync(new TopicPartition(topic, new Partition(0)), new Message<string, string> { Key = eventId.ToString(), Value = payload });
            await using (var scope = fixture.Services.CreateAsyncScope()) {
                await scope.ServiceProvider.GetRequiredService<IChatService>().CreateMessageAsync(roomId, seed.Users[0], "Tin nhắn thứ hai");
            }
            await Until(async () => await Processed(fixture) == 2);
            await using var check = fixture.Services.CreateAsyncScope();
            var notifications = await check.ServiceProvider.GetRequiredService<AppDbContext>().Notifications.OrderBy(n => n.CreatedAt).ToListAsync();
            Assert.Equal(2, notifications.Count);
            Assert.All(notifications, n => { Assert.Equal(seed.Users[1], n.UserId); Assert.Equal("CHAT_ROOM", n.TargetType); Assert.Equal(roomId, n.TargetId); });
            Assert.Equal(NotificationType.CHAT_MENTION, notifications[0].Type);
            Assert.Equal(NotificationType.CHAT_MESSAGE, notifications[1].Type);
        } finally {
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            await dispatcher.StopAsync(timeout.Token); await consumer.StopAsync(timeout.Token);
            await admin.DeleteTopicsAsync([topic]);
        }
    }
    private static async Task<int> Processed(PostgresFixture fixture) {
        await using var scope = fixture.Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<AppDbContext>().ProcessedMessages.CountAsync(m => m.Consumer == KafkaTopics.CHAT_MESSAGE_CREATED);
    }
    private static async Task Until(Func<Task<bool>> check) {
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        while (!await check()) await Task.Delay(150, deadline.Token);
    }
}
