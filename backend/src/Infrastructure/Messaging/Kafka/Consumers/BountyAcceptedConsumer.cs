using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;

public sealed class BountyAcceptedConsumer(
    IOptions<KafkaOptions> options,
    IServiceScopeFactory scopes,
    ILogger<BountyAcceptedConsumer> logger)
    : KafkaConsumerBase<BountyAcceptedEvent>(KafkaTopics.BOUNTY_ACCEPTED, options, scopes, logger)
{
    protected override async Task ProcessEventAsync(BountyAcceptedEvent message, IServiceProvider services, CancellationToken ct)
    {
        var uow = services.GetRequiredService<IUnitOfWork>();
        var bounty = await uow.ChoreBounties.GetByIdAsync(message.BountyId, ct)
            ?? throw new InvalidDataException("Bounty not found.");
        var occurrence = await uow.ChoreOccurrences.GetByIdAsync(bounty.ChoreOccurrenceId, ct)
            ?? throw new InvalidDataException("Occurrence not found.");
        if (!occurrence.Responsibilities.Any(r => r.UserId == message.AcceptedByUserId && r.Reason == "BOUNTY"))
            throw new InvalidDataException("Bounty acceptance cannot be verified.");

        var houseId = occurrence.Chore.HouseId;
        await services.GetRequiredService<IAchievementCheckService>()
            .CheckAchievementsAsync(houseId, message.AcceptedByUserId, AchievementConditionType.BOUNTIES_CLAIMED, ct);

        var realtime = services.GetService<INotificationRealtimePublisher>();
        if (realtime != null)
        {
            var members = await uow.HouseMembers.GetByHouseIdAsync(houseId, ct);
            foreach (var member in members.Where(m => m.Status == HouseMemberStatus.ACTIVE))
            {
                await realtime.BountyBoardChangedAsync(member.UserId, houseId, ct);
            }
        }
    }
}
