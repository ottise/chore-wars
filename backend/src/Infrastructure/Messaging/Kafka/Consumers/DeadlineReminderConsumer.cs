using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public class DeadlineReminderConsumer : KafkaConsumerBase<DeadlineReminderEvent>
{
    public DeadlineReminderConsumer(
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<DeadlineReminderConsumer> logger) 
        : base(KafkaTopics.DEADLINE_REMINDER, options, scopeFactory, logger)
    {
    }

    protected override async Task ProcessEventAsync(DeadlineReminderEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken)
    {
        var notificationService = serviceProvider.GetRequiredService<INotificationService>();

        await notificationService.CreateNotificationAsync(
            userId: @event.AssignedUserId,
            houseId: @event.HouseId,
            title: "Chore Deadline Approaching",
            message: "One of your assigned chores is due in less than 2 hours. Please complete it soon to avoid a penalty.",
            type: "CHORE_REMINDER",
            cancellationToken: cancellationToken);
    }
}
