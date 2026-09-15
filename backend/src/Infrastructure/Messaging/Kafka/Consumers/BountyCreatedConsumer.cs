using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public class BountyCreatedConsumer : KafkaConsumerBase<BountyCreatedEvent>
{
    public BountyCreatedConsumer(
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<BountyCreatedConsumer> logger) 
        : base(KafkaTopics.BOUNTY_CREATED, options, scopeFactory, logger)
    {
    }

    protected override async Task ProcessEventAsync(BountyCreatedEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken)
    {
        var unitOfWork = serviceProvider.GetRequiredService<IUnitOfWork>();
        var notificationService = serviceProvider.GetRequiredService<INotificationService>();

        var houseMembers = await unitOfWork.HouseMembers.GetByHouseIdAsync(@event.HouseId, cancellationToken);
        
        foreach (var member in houseMembers)
        {
            await notificationService.CreateNotificationAsync(
                userId: member.UserId,
                houseId: @event.HouseId,
                title: "New Bounty!",
                message: "A new bounty has been posted in your house.",
                type: "BOUNTY_POSTED",
                cancellationToken: cancellationToken);
        }
    }
}
