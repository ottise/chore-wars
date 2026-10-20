using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Events;

namespace ChoreWars.Application.Services;

public class SeasonEndService : ISeasonEndService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly IOverduePenaltyService? _penalties;
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<SeasonEndService> _logger;
    private readonly IEventPublisher _eventPublisher;

    public SeasonEndService(IUnitOfWork unitOfWork, ILogger<SeasonEndService> logger, IEventPublisher eventPublisher, IHouseMutationCoordinator? mutations = null, IOverduePenaltyService? penalties = null, TimeProvider? clock = null)
    {
        _clock = clock ?? TimeProvider.System;
        _mutations = mutations; _penalties = penalties;
        _unitOfWork = unitOfWork;
        _logger = logger;
        _eventPublisher = eventPublisher;
    }

    public async Task ProcessEndedSeasonsAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting ProcessEndedSeasonsAsync.");

        var now = _clock.GetUtcNow().UtcDateTime;
        var seasons = await _unitOfWork.Seasons.GetActiveSeasonsAsync(now, cancellationToken);
        var endedSeasons = seasons.Where(s => s.EndDate < now).ToList();

        foreach (var candidate in endedSeasons) {
            try {
                if (_mutations != null) await _mutations.RunAsync(candidate.HouseId, () => FinalizeAsync(candidate.Id,now,cancellationToken),cancellationToken);
                else await FinalizeAsync(candidate.Id,now,cancellationToken);
            } catch (Exception ex) { await _unitOfWork.RollbackTransactionAsync(cancellationToken); _logger.LogError(ex,"Season finalization failed for {SeasonId}",candidate.Id); }
        }
    }
    public async Task FinalizeSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default) {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId,cancellationToken) ?? throw new ChoreWars.Domain.Exceptions.NotFoundException("Season not found.");
        if (_mutations != null) await _mutations.RunAsync(season.HouseId,() => FinalizeAsync(seasonId,_clock.GetUtcNow().UtcDateTime,cancellationToken),cancellationToken);
        else await FinalizeAsync(seasonId,_clock.GetUtcNow().UtcDateTime,cancellationToken);
    }
    private async Task FinalizeAsync(Guid seasonId, DateTime now, CancellationToken cancellationToken = default) {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId,cancellationToken);
        if (season == null || season.Status != SeasonStatus.ACTIVE || season.EndDate >= now) return;
        try {
                await _unitOfWork.BeginTransactionAsync(cancellationToken);



                if (_penalties != null) {
                    var occurrences = await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(season.Id,cancellationToken);
                    foreach (var occurrence in occurrences.Where(o => o.DueDate < season.EndDate && o.AssignedUserId.HasValue))
                        await _penalties.ApplyUntilAsync(occurrence.Id,season.EndDate,cancellationToken);
                }
                season.Status = SeasonStatus.COMPLETED;
                season.FinalizedAt = now;
                _unitOfWork.Seasons.Update(season);
                var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken);
                var seasonKarma = await _unitOfWork.KarmaTransactions.GetBySeasonIdAsync(season.Id, cancellationToken);
                
                var rankedMembers = members.Select(m => {
                    var memberTx = seasonKarma.Where(t => t.UserId == m.UserId).ToList();
                    return new {
                        Member = m,
                        TotalKarma = memberTx.Sum(t => t.Amount),
                        CompletedCount = memberTx.Count(t => t.Type == KarmaTransactionType.CHORE_COMPLETED),
                        BonusCount = memberTx.Where(t => t.Type is KarmaTransactionType.BONUS or KarmaTransactionType.BOUNTY_REWARD).Sum(t => t.Amount)
                    };
                })
                .OrderByDescending(x => x.TotalKarma)
                .ThenByDescending(x => x.CompletedCount)
                .ThenByDescending(x => x.BonusCount)
                .ThenBy(x => x.Member.JoinedAt)
                .ThenBy(x => x.Member.UserId)
                .ToList();

                // Aggregate Karma for Ranking
                int rank = 1;
                foreach (var item in rankedMembers)
                {
                    var ranking = new SeasonRanking
                    {
                        Id = Guid.NewGuid(),
                        SeasonId = season.Id,
                        UserId = item.Member.UserId,
                        TotalKarma = item.TotalKarma,
                        Rank = rank,
                        ChoresCompleted = item.CompletedCount
                    };
                    
                    await _unitOfWork.SeasonRankings.AddAsync(ranking, cancellationToken);

                    // Reward Rank #1 with Chore Pass
                    if (rank == 1)
                    {
                        var seasonRewards = await _unitOfWork.Rewards.GetBySeasonIdAsync(season.Id, cancellationToken);
                        var chorePassReward = seasonRewards.FirstOrDefault(reward => reward.Type == RewardType.CHORE_PASS);
                        if (chorePassReward == null)
                        {
                            chorePassReward = new Reward
                            {
                                Id = Guid.NewGuid(),
                                HouseId = season.HouseId,
                                SeasonId = season.Id,
                                Name = "Chore Pass",
                                Description = "Skip one assignment without a penalty. The chore will be reassigned.",
                                Type = RewardType.CHORE_PASS
                            };
                            await _unitOfWork.Rewards.AddAsync(chorePassReward, cancellationToken);
                        }

                        var redemption = new RewardRedemption
                        {
                            Id = Guid.NewGuid(),
                            RewardId = chorePassReward.Id,
                            UserId = item.Member.UserId,
                            Status = RewardRedemptionStatus.UNCLAIMED,
                            ClaimDeadline = now.AddDays(7),
                            UsageDeadline = null
                        };
                        await _unitOfWork.RewardRedemptions.AddAsync(redemption, cancellationToken);
                    }

                    // Spendable household balance persists across seasons.
                    
                    rank++;
                }

                await _unitOfWork.SaveChangesAsync(cancellationToken);
                await _eventPublisher.PublishAsync(new SeasonEndedEvent(season.Id, season.HouseId), cancellationToken);
                await _unitOfWork.SaveChangesAsync(cancellationToken);
                await _unitOfWork.CommitTransactionAsync(cancellationToken);

                _logger.LogInformation($"Processed end of season {season.Id}");
        } catch { await _unitOfWork.RollbackTransactionAsync(cancellationToken); throw; }
    }
}
