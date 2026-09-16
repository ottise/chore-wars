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
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<SeasonEndService> _logger;
    private readonly IEventPublisher _eventPublisher;

    public SeasonEndService(IUnitOfWork unitOfWork, ILogger<SeasonEndService> logger, IEventPublisher eventPublisher)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
        _eventPublisher = eventPublisher;
    }

    public async Task ProcessEndedSeasonsAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting ProcessEndedSeasonsAsync.");

        var now = DateTime.UtcNow;
        var seasons = await _unitOfWork.Seasons.GetActiveSeasonsAsync(now, cancellationToken);
        var endedSeasons = seasons.Where(s => s.EndDate < now).ToList();

        foreach (var season in endedSeasons)
        {
            try
            {
                await _unitOfWork.BeginTransactionAsync(cancellationToken);

                season.Status = SeasonStatus.COMPLETED;
                _unitOfWork.Seasons.Update(season);

                var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken);
                var seasonKarma = await _unitOfWork.KarmaTransactions.GetBySeasonIdAsync(season.Id, cancellationToken);
                
                var rankedMembers = members.Select(m => {
                    var memberTx = seasonKarma.Where(t => t.UserId == m.UserId).ToList();
                    return new {
                        Member = m,
                        TotalKarma = m.KarmaBalance,
                        CompletedCount = memberTx.Count(t => t.Type == KarmaTransactionType.CHORE_COMPLETED),
                        BonusCount = memberTx.Count(t => t.Type == KarmaTransactionType.BONUS)
                    };
                })
                .OrderByDescending(x => x.TotalKarma)
                .ThenByDescending(x => x.CompletedCount)
                .ThenByDescending(x => x.BonusCount)
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
                        Rank = rank
                    };
                    
                    await _unitOfWork.SeasonRankings.AddAsync(ranking, cancellationToken);

                    // Reward Rank #1 with Chore Pass
                    if (rank == 1)
                    {
                        var chorePassReward = await _unitOfWork.Rewards.GetChorePassRewardAsync(cancellationToken);
                        if (chorePassReward != null)
                        {
                            var redemption = new RewardRedemption
                            {
                                Id = Guid.NewGuid(),
                                RewardId = chorePassReward.Id,
                                UserId = item.Member.UserId,
                                Status = RewardRedemptionStatus.UNCLAIMED,
                                ClaimDeadline = now.AddDays(7), // Example: 7 days to claim
                                UsageDeadline = now.AddDays(30) // 30 days to use
                            };
                            await _unitOfWork.RewardRedemptions.AddAsync(redemption, cancellationToken);
                        }
                    }

                    // Reset Karma for next season
                    item.Member.KarmaBalance = 0;
                    _unitOfWork.HouseMembers.Update(item.Member);
                    
                    rank++;
                }

                await _unitOfWork.SaveChangesAsync(cancellationToken);
                await _unitOfWork.CommitTransactionAsync(cancellationToken);

                await _eventPublisher.PublishAsync(new SeasonEndedEvent(season.Id, season.HouseId), cancellationToken);

                _logger.LogInformation($"Processed end of season {season.Id}");
            }
            catch (Exception ex)
            {
                await _unitOfWork.RollbackTransactionAsync(cancellationToken);
                _logger.LogError(ex, $"Error processing end of season {season.Id}.");
            }
        }

        _logger.LogInformation("Completed ProcessEndedSeasonsAsync.");
    }
}
