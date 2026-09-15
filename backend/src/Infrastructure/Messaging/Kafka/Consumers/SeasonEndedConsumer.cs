using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public class SeasonEndedConsumer : KafkaConsumerBase<SeasonEndedEvent>
{
    public SeasonEndedConsumer(
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<SeasonEndedConsumer> logger) 
        : base(KafkaTopics.SEASON_ENDED, options, scopeFactory, logger)
    {
    }

    protected override async Task ProcessEventAsync(SeasonEndedEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken)
    {
        var unitOfWork = serviceProvider.GetRequiredService<IUnitOfWork>();
        var notificationService = serviceProvider.GetRequiredService<INotificationService>();
        var cacheService = serviceProvider.GetRequiredService<ICacheService>();

        var houseMembers = await unitOfWork.HouseMembers.GetByHouseIdAsync(@event.HouseId, cancellationToken);
        
        foreach (var member in houseMembers)
        {
            await notificationService.CreateNotificationAsync(
                userId: member.UserId,
                houseId: @event.HouseId,
                title: "Season Ended",
                message: "The current season has ended! Check the leaderboard for your ranking and rewards.",
                type: "SYSTEM",
                cancellationToken: cancellationToken);
        }

        // Cache invalidation (e.g. clearing cached active season for the house)
        var cacheKey = $"active_season_{@event.HouseId}";
        await cacheService.RemoveAsync(cacheKey, cancellationToken);
    }
}
