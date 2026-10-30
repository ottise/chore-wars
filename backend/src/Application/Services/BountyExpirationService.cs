using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Events;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Application.Services;

public class BountyExpirationService(IUnitOfWork uow, ILogger<BountyExpirationService> logger, IEventPublisher events, IHouseMutationCoordinator? mutations = null, TimeProvider? clock = null, IOverduePenaltyService? penalties = null) : IBountyExpirationService
{
    private TimeProvider Clock => clock ?? TimeProvider.System;
    public async Task ProcessExpiredBountiesAsync(CancellationToken cancellationToken = default)
    {
        var expired = await uow.ChoreBounties.GetExpiredEligibleBountiesAsync(Clock.GetUtcNow().UtcDateTime, cancellationToken);
        foreach (var candidate in expired)
        {
            try
            {
                if (mutations != null) await mutations.RunAsync(candidate.ChoreOccurrence.Chore.HouseId, () => ProcessAsync(candidate.Id, cancellationToken), cancellationToken);
                else await ProcessAsync(candidate.Id, cancellationToken);
            }
            catch (Exception ex) { logger.LogError(ex, "Bounty expiry failed for {BountyId}", candidate.Id); }
        }
    }
    private async Task ProcessAsync(Guid id, CancellationToken ct)
    {
        var bounty = await uow.ChoreBounties.GetByIdAsync(id, ct);
        if (bounty == null || bounty.Status != BountyStatus.OPEN || bounty.ExpiresAt > Clock.GetUtcNow().UtcDateTime) return;
        var occurrence = await uow.ChoreOccurrences.GetByIdAsync(bounty.ChoreOccurrenceId, ct);
        if (occurrence == null) return;
        if (occurrence.Status == ChoreOccurrenceStatus.ASSIGNED && occurrence.DueDate > Clock.GetUtcNow().UtcDateTime) {
            // Legacy listings used now+24h. Their cutoff is the original chore deadline under the current policy.
            bounty.ExpiresAt = occurrence.DueDate;
            uow.ChoreBounties.Update(bounty);
            await uow.SaveChangesAsync(ct);
            return;
        }
        await uow.BeginTransactionAsync(ct);
        try
        {
            bounty.Status = BountyStatus.EXPIRED;
            uow.ChoreBounties.Update(bounty);
            // Expiring a listing never changes the chore's deadline, assignee or compensation.
            // The normal overdue lifecycle remains responsible for overdue chores.
            await events.PublishAsync(new BountyExpiredEvent(bounty.Id, occurrence.Id, bounty.PostedByUserId, occurrence.Chore.HouseId), ct);
            await uow.SaveChangesAsync(ct);
            await uow.CommitTransactionAsync(ct);
        }
        catch { await uow.RollbackTransactionAsync(ct); throw; }
    }
}
