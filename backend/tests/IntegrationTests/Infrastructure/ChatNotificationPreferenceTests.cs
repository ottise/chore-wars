using System.Reflection;
using System.Text.Json;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using ChoreWars.Infrastructure.Messaging.Kafka.Consumers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using ChoreWars.Application.DTOs.Notification;
using Moq;

namespace IntegrationTests.Infrastructure;

public sealed class ChatNotificationPreferenceTests
{
    [PostgresFact]
    public async Task MutedMemberReceivesNoNewMessageOrMentionNotificationsAndCanEnableAgain()
    {
        var realtime = new Mock<INotificationRealtimePublisher>();
        realtime.Setup(x => x.PublishAsync(It.IsAny<NotificationResponse>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        await using var fixture = await PostgresFixture.CreateAsync(configure: services => services.AddSingleton(realtime.Object));
        var seed = await CoreConcurrencyTests.Seed(fixture);
        var scopes = fixture.Services.GetRequiredService<IServiceScopeFactory>();
        using var consumer = new ChatMessageCreatedConsumer(Options.Create(new KafkaOptions()), scopes, NullLogger<ChatMessageCreatedConsumer>.Instance);
        var process = typeof(ChatMessageCreatedConsumer).GetMethod("ProcessEventAsync", BindingFlags.Instance | BindingFlags.NonPublic)!;
        for (var round = 0; round < 2; round++)
        {
            await using (var settings = fixture.Services.CreateAsyncScope())
            {
                var chat = settings.ServiceProvider.GetRequiredService<IChatService>();
                await chat.SetNotificationsEnabledAsync(seed.HouseId, seed.Users[1], round == 1);
            }
            await using var scope = fixture.Services.CreateAsyncScope();
            var service = scope.ServiceProvider.GetRequiredService<IChatService>();
            Assert.Equal(round == 1, await service.GetNotificationsEnabledAsync(seed.HouseId, seed.Users[1]));
            var room = await service.GetHouseRoomAsync(seed.HouseId, seed.Users[0]);
            var message = await service.CreateTextMessageAsync(room.Id, seed.Users[0], "@all hello", Guid.NewGuid());
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var events = await db.OutboxMessages.Where(x => x.Topic == KafkaTopics.CHAT_MESSAGE_CREATED).ToListAsync();
            var value = events.Select(x => JsonSerializer.Deserialize<ChatMessageCreatedEvent>(x.Payload)!).Single(x => x.MessageId == message.Id);
            await (Task)process.Invoke(consumer, [value, scope.ServiceProvider, CancellationToken.None])!;
            Assert.Equal(round, await db.Notifications.CountAsync(x => x.UserId == seed.Users[1]));
            Assert.Equal(round + 1, await db.Notifications.CountAsync(x => x.UserId == seed.Users[2]));
        }
    }
}
