using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public class ChoreOverdueConsumer : KafkaConsumerBase<ChoreOverdueEvent>
{
    public ChoreOverdueConsumer(
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<ChoreOverdueConsumer> logger) 
        : base(KafkaTopics.CHORE_OVERDUE, options, scopeFactory, logger)
    {
    }

    protected override async Task ProcessEventAsync(ChoreOverdueEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken)
    {
        var notificationService = serviceProvider.GetRequiredService<INotificationService>();

        await notificationService.CreateNotificationAsync(
            userId: @event.UserId,
            houseId: @event.HouseId,
            title: "Chore Overdue",
            message: "One of your assigned chores is overdue and you have been penalized.",
            type: "CHORE_REMINDER",
            cancellationToken: cancellationToken);
    }
}
