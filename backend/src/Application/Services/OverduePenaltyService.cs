using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Events;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Application.Services;
public class OverduePenaltyService(IUnitOfWork uow, ILogger<OverduePenaltyService> logger, IEventPublisher events, IKarmaService karma, IHouseMutationCoordinator? mutations = null, TimeProvider? clock = null) : IOverduePenaltyService {
    private TimeProvider Clock => clock ?? TimeProvider.System;
    public async Task ProcessOverduePenaltiesAsync(CancellationToken cancellationToken = default) {
        var now = Clock.GetUtcNow().UtcDateTime;
        var candidates = await uow.ChoreOccurrences.GetOverdueEligibleOccurrencesAsync(now,cancellationToken);
        foreach (var occurrence in candidates) {
            try { await ApplyUntilAsync(occurrence.Id,now,cancellationToken); }
            catch (Exception ex) { logger.LogError(ex,"Penalty processing failed for {OccurrenceId}",occurrence.Id); }
        }
    }
    public async Task ApplyUntilAsync(Guid occurrenceId, DateTime cutoff, CancellationToken cancellationToken = default) {
        var occurrence = await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,cancellationToken);
        if (occurrence == null) return;
        if (mutations != null) await mutations.RunAsync(occurrence.Chore.HouseId,() => ApplyCoreAsync(occurrenceId,cutoff,cancellationToken),cancellationToken);
        else await ApplyCoreAsync(occurrenceId,cutoff,cancellationToken);
    }
    private async Task ApplyCoreAsync(Guid id, DateTime cutoff, CancellationToken ct) {
        var occurrence = await uow.ChoreOccurrences.GetByIdAsync(id,ct);
        if (occurrence?.AssignedUserId == null || occurrence.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED) return;
        var season = await uow.Seasons.GetByIdAsync(occurrence.SeasonId,ct);
        if (season == null || season.Status is SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.CANCELLED) return;
        var scoringCutoff = cutoff < season.EndDate ? cutoff : season.EndDate;
        await uow.BeginTransactionAsync(ct);
        try {
            var episode = await ChoreResponsibilityService.EnsureAsync(uow,occurrence,cutoff,ct);
            var expected = Math.Clamp((int)((scoringCutoff - episode.Deadline).TotalHours / PenaltyConstants.PenaltyIntervalHours),0,PenaltyConstants.MaxPenaltyCount);
            if (season.Status == SeasonStatus.ACTIVE) {
                while (episode.PenaltiesApplied < expected) {
                    episode.PenaltiesApplied++;
                    await karma.AddKarmaTransactionAsync(occurrence.Chore.HouseId, occurrence.SeasonId, episode.UserId, -PenaltyConstants.SinglePenalty, KarmaTransactionType.PENALTY, episode.Id, ct, effectiveAt: scoringCutoff, penaltyStep: episode.PenaltiesApplied);
                }
            }
            occurrence.PenaltyCount = episode.PenaltiesApplied;
            var previous = occurrence.Status;
            if (cutoff > occurrence.DueDate) occurrence.Status = episode.PenaltiesApplied >= PenaltyConstants.MaxPenaltyCount ? ChoreOccurrenceStatus.CRITICAL_OVERDUE : ChoreOccurrenceStatus.OVERDUE;
            uow.ChoreOccurrences.Update(occurrence);
            if (previous != occurrence.Status) await events.PublishAsync(new ChoreOverdueEvent(occurrence.Id,occurrence.AssignedUserId.Value,occurrence.Chore.HouseId),ct);
            await uow.SaveChangesAsync(ct);
            await uow.CommitTransactionAsync(ct);
        } catch { await uow.RollbackTransactionAsync(ct); throw; }
    }
}
