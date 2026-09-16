using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public class BountyExpiredConsumer : KafkaConsumerBase<BountyExpiredEvent>
{
    public BountyExpiredConsumer(
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<BountyExpiredConsumer> logger) 
        : base(KafkaTopics.BOUNTY_EXPIRED, options, scopeFactory, logger)
    {
    }

    protected override async Task ProcessEventAsync(BountyExpiredEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken)
    {
        var notificationService = serviceProvider.GetRequiredService<INotificationService>();

        await notificationService.CreateNotificationAsync(
            userId: @event.PostedByUserId,
            houseId: @event.HouseId,
            title: "Bounty Expired",
            message: $"Your bounty has expired and the chore was forced-reassigned.",
            type: "SYSTEM_ALERT",
            cancellationToken: cancellationToken);
    }
}
