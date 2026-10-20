using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Events;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Application.Services;
public class BountyExpirationService(IUnitOfWork uow, ILogger<BountyExpirationService> logger, IEventPublisher events, IHouseMutationCoordinator? mutations = null, TimeProvider? clock = null, IOverduePenaltyService? penalties = null) : IBountyExpirationService {
    private TimeProvider Clock => clock ?? TimeProvider.System;
    public async Task ProcessExpiredBountiesAsync(CancellationToken cancellationToken = default) {
        var expired = await uow.ChoreBounties.GetExpiredEligibleBountiesAsync(Clock.GetUtcNow().UtcDateTime, cancellationToken);
        foreach (var candidate in expired) {
            try {
                if (mutations != null) await mutations.RunAsync(candidate.ChoreOccurrence.Chore.HouseId, () => ProcessAsync(candidate.Id, cancellationToken), cancellationToken);
                else await ProcessAsync(candidate.Id, cancellationToken);
            } catch (Exception ex) { logger.LogError(ex, "Bounty expiry failed for {BountyId}", candidate.Id); }
        }
    }
    private async Task ProcessAsync(Guid id, CancellationToken ct) {
        var bounty = await uow.ChoreBounties.GetByIdAsync(id, ct);
        if (bounty == null || bounty.Status != BountyStatus.OPEN || bounty.ExpiresAt > Clock.GetUtcNow().UtcDateTime) return;
        var occurrence = await uow.ChoreOccurrences.GetByIdAsync(bounty.ChoreOccurrenceId, ct);
        if (occurrence == null) return;
        await uow.BeginTransactionAsync(ct);
        try {
            bounty.Status = BountyStatus.EXPIRED;
            uow.ChoreBounties.Update(bounty);
            var payments = await uow.PaymentObligations.GetByHouseIdAsync(occurrence.Chore.HouseId, ct);
            if (occurrence.Status is not (ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED) && !payments.Any(p => p.OccurrenceId == occurrence.Id && p.Reason == PaymentObligationReason.FORCED_REASSIGNMENT)) {
                if (penalties != null && occurrence.DueDate < Clock.GetUtcNow().UtcDateTime)
                    await penalties.ApplyUntilAsync(occurrence.Id,Clock.GetUtcNow().UtcDateTime,ct);
                var oldDeadline = occurrence.DueDate;
                occurrence.DueDate = Clock.GetUtcNow().UtcDateTime.AddHours(24);
                var selected = await ReplacementSelector.SelectAsync(uow, occurrence, bounty.PostedByUserId, ct);
                if (selected.HasValue) {
                    var replacementDeadline = occurrence.DueDate;
                    occurrence.DueDate = oldDeadline; // Preserve the previous episode's original deadline.
                    await ChoreResponsibilityService.AssignAsync(uow, occurrence, selected.Value, "FORCED_BOUNTY", replacementDeadline, Clock.GetUtcNow().UtcDateTime, ct);
                    await uow.PaymentObligations.AddAsync(new PaymentObligation { Id = Guid.NewGuid(), HouseId = occurrence.Chore.HouseId, SeasonId = occurrence.SeasonId, OccurrenceId = occurrence.Id, DebtorUserId = bounty.PostedByUserId, CreditorUserId = selected.Value, Amount = bounty.Amount * BountyConstants.ForcedReassignmentMultiplier, Reason = PaymentObligationReason.FORCED_REASSIGNMENT, Status = PaymentObligationStatus.PENDING, CreatedAt = Clock.GetUtcNow().UtcDateTime }, ct);
                } else { occurrence.DueDate = oldDeadline; } // No candidate: preserve responsibility for household resolution.
            }
            await events.PublishAsync(new BountyExpiredEvent(bounty.Id, occurrence.Id, bounty.PostedByUserId, occurrence.Chore.HouseId), ct);
            await uow.SaveChangesAsync(ct);
            await uow.CommitTransactionAsync(ct);
        } catch { await uow.RollbackTransactionAsync(ct); throw; }
    }
}
