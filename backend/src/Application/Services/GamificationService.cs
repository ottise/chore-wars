using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Gamification;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class GamificationService : IGamificationService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;

    public GamificationService(IUnitOfWork unitOfWork, IMapper mapper)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
    }

    public async Task<int> GetKarmaBalanceAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var activeSeason = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason == null)
            return 0;

        var ranking = await _unitOfWork.SeasonRankings.GetBySeasonAndUserIdAsync(activeSeason.Id, userId, cancellationToken);
        return ranking?.TotalKarma ?? 0;
    }

    public async Task<IEnumerable<RewardResponse>> GetSeasonRewardsAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException("Season not found");

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var rewards = await _unitOfWork.Rewards.GetBySeasonIdAsync(seasonId, cancellationToken);
        return _mapper.Map<IEnumerable<RewardResponse>>(rewards);
    }

    public async Task UseChorePassAsync(Guid rewardId, Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default)
    {
        var reward = await _unitOfWork.Rewards.GetByIdAsync(rewardId, cancellationToken);
        if (reward == null || reward.Type != RewardType.CHORE_PASS)
            throw new ConflictException("Invalid reward or not a chore pass.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException("ChoreOccurrence not found");

        if (occurrence.AssignedUserId != userId)
            throw new ForbiddenException("Can only skip your own chore.");

        var ranking = await _unitOfWork.SeasonRankings.GetBySeasonAndUserIdAsync(reward.SeasonId, userId, cancellationToken);
        if (ranking == null || ranking.Rank != 1)
            throw new ForbiddenException("You must be Rank 1 to use a Chore Pass.");

        var existingRedemption = await _unitOfWork.RewardRedemptions.GetByRewardAndUserIdAsync(rewardId, userId, cancellationToken);
        if (existingRedemption != null)
            throw new ConflictException("You have already used this Chore Pass.");
        
        occurrence.Status = ChoreOccurrenceStatus.SKIPPED;
        
        var redemption = new ChoreWars.Domain.Entities.RewardRedemption
        {
            Id = Guid.NewGuid(),
            RewardId = rewardId,
            UserId = userId,
            Status = RewardRedemptionStatus.USED,
            RedeemedAt = DateTime.UtcNow,
            UsedAt = DateTime.UtcNow
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            await _unitOfWork.RewardRedemptions.AddAsync(redemption, cancellationToken);
            // Reassignment logic would typically be handled by a worker or event handler
            
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<AchievementResponse>> GetAchievementsAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var achievements = await _unitOfWork.Achievements.GetByHouseIdAsync(houseId, cancellationToken);
        return _mapper.Map<IEnumerable<AchievementResponse>>(achievements);
    }
}
