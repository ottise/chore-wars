using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public sealed class ChatMessageCreatedConsumer(IOptions<KafkaOptions> options, IServiceScopeFactory scopes,
    ILogger<ChatMessageCreatedConsumer> logger)
    : KafkaConsumerBase<ChatMessageCreatedEvent>(KafkaTopics.CHAT_MESSAGE_CREATED, options, scopes, logger)
{
    protected override async Task ProcessEventAsync(ChatMessageCreatedEvent value, IServiceProvider services, CancellationToken ct)
    {
        var db = services.GetRequiredService<AppDbContext>();
        var message = await db.ChatMessages.AsNoTracking().Where(m => m.Id == value.MessageId && m.Room.HouseId == value.HouseId)
            .Select(m => new { m.SenderId, m.RoomId, m.CreatedAt }).SingleAsync(ct);
        var members = (await services.GetRequiredService<IUnitOfWork>().HouseMembers.GetByHouseIdAsync(value.HouseId, ct))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE && m.UserId != message.SenderId && m.JoinedAt <= message.CreatedAt)
            .Select(m => m.UserId).ToHashSet();
        var realtime = services.GetRequiredService<INotificationRealtimePublisher>();
        foreach (var user in members) await realtime.ChatUnreadChangedAsync(user, value.HouseId, ct);
        var muted = (await services.GetRequiredService<IUnitOfWork>().HouseMembers.GetByHouseIdAsync(value.HouseId, ct)).Where(m => m.ChatNotificationsMuted).Select(m => m.UserId).ToHashSet();
        var notifications = services.GetRequiredService<INotificationService>();
        foreach (var recipient in value.RecipientIds.Distinct().Where(id => members.Contains(id) && !muted.Contains(id)))
        {
            var mentioned = value.MentionedIds.Contains(recipient);
            await notifications.CreateNotificationAsync(recipient, value.HouseId,
                mentioned ? "You were mentioned in chat" : "New household message",
                mentioned ? "A member mentioned you. Open chat to view the message." : "Open household chat to read the new message.",
                (mentioned ? NotificationType.CHAT_MENTION : NotificationType.CHAT_MESSAGE).ToString(),
                ChatMentions.RoomTarget, message.RoomId, ct);
        }
    }
}
