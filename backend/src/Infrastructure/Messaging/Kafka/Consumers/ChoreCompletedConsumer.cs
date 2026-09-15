using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public class ChoreCompletedConsumer : KafkaConsumerBase<ChoreCompletedEvent>
{
    public ChoreCompletedConsumer(
        IOptions<KafkaOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<ChoreCompletedConsumer> logger) 
        : base(KafkaTopics.CHORE_COMPLETED, options, scopeFactory, logger)
    {
    }

    protected override async Task ProcessEventAsync(ChoreCompletedEvent @event, IServiceProvider serviceProvider, CancellationToken cancellationToken)
    {
        var achievementCheckService = serviceProvider.GetRequiredService<IAchievementCheckService>();
        var notificationService = serviceProvider.GetRequiredService<INotificationService>();

        // Check for achievements
        await achievementCheckService.CheckAchievementsAsync(@event.HouseId, @event.UserId, AchievementConditionType.CHORES_COMPLETED, cancellationToken);
        await achievementCheckService.CheckAchievementsAsync(@event.HouseId, @event.UserId, AchievementConditionType.KARMA_EARNED, cancellationToken);
        
        // Notify the user that they completed a chore (optional, mostly an example)
        await notificationService.CreateNotificationAsync(
            userId: @event.UserId,
            houseId: @event.HouseId,
            title: "Chore Completed",
            message: "You successfully completed a chore!",
            type: "CHORE_REMINDER", // Re-using type, or could be ACHIEVEMENT
            cancellationToken: cancellationToken);
    }
}
