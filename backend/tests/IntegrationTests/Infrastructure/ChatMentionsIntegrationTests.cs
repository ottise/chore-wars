using System.Text.Json;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using System.Buffers.Binary;

namespace IntegrationTests.Infrastructure;

public sealed class ChatMentionsIntegrationTests
{
    [PostgresTheory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task ImageAndVoiceMessagesAlsoProduceOneChatNotificationEventOnRetry(bool voice)
    {
        var storage = new Mock<IMediaStorage>();
        storage.Setup(s => s.WriteAsync(It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        await using var fixture = await PostgresFixture.CreateAsync(configure: services => services.AddScoped(_ => storage.Object));
        var seed = await CoreConcurrencyTests.Seed(fixture);
        await using var scope = fixture.Services.CreateAsyncScope();
        var room = await scope.ServiceProvider.GetRequiredService<IChatService>().GetHouseRoomAsync(seed.HouseId, seed.Users[0]);
        byte[] data = [255, 216, 255, 1];
        if (voice) {
            data = new byte[44 + 32000];
            "RIFF"u8.CopyTo(data); BinaryPrimitives.WriteUInt32LittleEndian(data.AsSpan(4), (uint)data.Length - 8);
            "WAVEfmt "u8.CopyTo(data.AsSpan(8)); BinaryPrimitives.WriteUInt32LittleEndian(data.AsSpan(16), 16);
            BinaryPrimitives.WriteUInt16LittleEndian(data.AsSpan(20), 1); BinaryPrimitives.WriteUInt16LittleEndian(data.AsSpan(22), 1);
            BinaryPrimitives.WriteUInt32LittleEndian(data.AsSpan(24), 16000); BinaryPrimitives.WriteUInt32LittleEndian(data.AsSpan(28), 32000);
            BinaryPrimitives.WriteUInt16LittleEndian(data.AsSpan(32), 2); BinaryPrimitives.WriteUInt16LittleEndian(data.AsSpan(34), 16);
            "data"u8.CopyTo(data.AsSpan(36)); BinaryPrimitives.WriteUInt32LittleEndian(data.AsSpan(40), 32000);
        }
        var media = scope.ServiceProvider.GetRequiredService<IMediaService>();
        var attachment = await media.UploadAsync(room.Id, seed.Users[0], data, default);
        var request = Guid.NewGuid();
        var first = await media.SendAsync(room.Id, attachment.Id, request, seed.Users[0], default);
        var retry = await media.SendAsync(room.Id, attachment.Id, request, seed.Users[0], default);
        Assert.Equal(first.Id, retry.Id); Assert.Equal(voice ? "AUDIO" : "IMAGE", first.MessageType);
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.ChatMessages.CountAsync());
        var value = JsonSerializer.Deserialize<ChatMessageCreatedEvent>((await db.OutboxMessages.SingleAsync()).Payload)!;
        Assert.Equal(2, value.RecipientIds.Length); Assert.Empty(value.MentionedIds);
    }

    [PostgresFact]
    public async Task MessageAndRecipientSnapshotCommitTogetherWithoutChatTextInKafka()
    {
        await using var fixture = await PostgresFixture.CreateAsync();
        var seed = await CoreConcurrencyTests.Seed(fixture);
        await using var scope = fixture.Services.CreateAsyncScope();
        var chat = scope.ServiceProvider.GetRequiredService<IChatService>();
        var room = await chat.GetHouseRoomAsync(seed.HouseId, seed.Users[0]);
        var content = $"@all @{{{seed.Users[1]}}} private-chat-marker";
        var clientId = Guid.NewGuid();
        var message = await chat.CreateTextMessageAsync(room.Id, seed.Users[0], content, clientId);
        var retry = await chat.CreateTextMessageAsync(room.Id, seed.Users[0], content, clientId);
        Assert.Equal(message.Id, retry.Id);
        await Assert.ThrowsAsync<ConflictException>(() => chat.CreateTextMessageAsync(room.Id, seed.Users[0], "different content", clientId));
        await Assert.ThrowsAsync<DomainException>(() => chat.CreateTextMessageAsync(room.Id, seed.Users[0], new string('a', 2001), Guid.NewGuid()));
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var outbox = await db.OutboxMessages.SingleAsync(x => x.Topic == KafkaTopics.CHAT_MESSAGE_CREATED);
        var value = JsonSerializer.Deserialize<ChatMessageCreatedEvent>(outbox.Payload)!;
        Assert.Equal(message.Id, value.MessageId);
        Assert.Equal(2, value.RecipientIds.Length); Assert.Equal(2, value.MentionedIds.Length);
        Assert.DoesNotContain(seed.Users[0], value.RecipientIds);
        Assert.DoesNotContain("private-chat-marker", outbox.Payload);
        Assert.Equal(content, (await db.ChatMessages.SingleAsync()).Content);
        await Assert.ThrowsAsync<DomainException>(() => chat.CreateMessageAsync(room.Id, seed.Users[0], $"@{{{Guid.NewGuid()}}} outsider"));
        Assert.Equal(1, await db.ChatMessages.CountAsync());
        Assert.Equal(1, await db.OutboxMessages.CountAsync());
        Assert.False(scope.ServiceProvider.GetRequiredService<IAIServiceStatus>().IsConfigured);
    }
}
