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
                
                // Aggregate Karma for Ranking
                int rank = 1;
                foreach (var member in members.OrderByDescending(m => m.KarmaBalance))
                {
                    var ranking = new SeasonRanking
                    {
                        Id = Guid.NewGuid(),
                        SeasonId = season.Id,
                        UserId = member.UserId,
                        TotalKarma = member.KarmaBalance,
                        Rank = rank
                    };
                    
                    await _unitOfWork.SeasonRankings.AddAsync(ranking, cancellationToken);

                    // Reward Rank #1 with Chore Pass
                    if (rank == 1)
                    {
                        var chorePassReward = await _unitOfWork.Rewards.GetChorePassRewardAsync(cancellationToken);
                        if (chorePassReward != null)
                        {
                            var userAchievement = new UserAchievement
                            {
                                Id = Guid.NewGuid(),
                                UserId = member.UserId,
                                AchievementId = chorePassReward.Id, // Actually should be UserReward, but keeping with existing model
                                UnlockedAt = now
                            };
                            await _unitOfWork.UserAchievements.AddAsync(userAchievement, cancellationToken);
                            
                            // Alternatively, increment a chore pass count on the member if that exists.
                        }
                    }

                    // Reset Karma for next season
                    member.KarmaBalance = 0;
                    _unitOfWork.HouseMembers.Update(member);
                    
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
