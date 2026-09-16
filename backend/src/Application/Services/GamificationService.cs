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

    public async Task ClaimRewardAsync(Guid redemptionId, Guid userId, CancellationToken cancellationToken = default)
    {
        var redemption = await _unitOfWork.RewardRedemptions.GetByIdAsync(redemptionId, cancellationToken);
        if (redemption == null)
            throw new NotFoundException("Reward redemption not found");

        if (redemption.UserId != userId)
            throw new ForbiddenException("Cannot claim someone else's reward");

        if (redemption.Status != RewardRedemptionStatus.UNCLAIMED)
            throw new ConflictException("Reward is already claimed or expired");

        if (redemption.ClaimDeadline.HasValue && redemption.ClaimDeadline.Value < DateTime.UtcNow)
        {
            redemption.Status = RewardRedemptionStatus.EXPIRED;
            _unitOfWork.RewardRedemptions.Update(redemption);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            throw new ConflictException("Claim deadline has passed");
        }

        redemption.Status = RewardRedemptionStatus.CLAIMED;
        
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.RewardRedemptions.Update(redemption);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task UseChorePassAsync(Guid redemptionId, Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default)
    {
        var redemption = await _unitOfWork.RewardRedemptions.GetByIdAsync(redemptionId, cancellationToken);
        if (redemption == null)
            throw new NotFoundException("Reward redemption not found");

        if (redemption.UserId != userId)
            throw new ForbiddenException("Cannot use someone else's reward");

        if (redemption.Status != RewardRedemptionStatus.CLAIMED)
            throw new ConflictException("Reward must be claimed before use, and cannot be already used");

        var reward = await _unitOfWork.Rewards.GetByIdAsync(redemption.RewardId, cancellationToken);
        if (reward == null || reward.Type != RewardType.CHORE_PASS)
            throw new ConflictException("Invalid reward or not a chore pass.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException("ChoreOccurrence not found");

        if (occurrence.AssignedUserId != userId)
            throw new ForbiddenException("Can only skip your own chore.");
        
        occurrence.Status = ChoreOccurrenceStatus.SKIPPED; // Initially marked skipped for original user, but we'll reassign it below
        
        redemption.Status = RewardRedemptionStatus.USED;
        redemption.UsedAt = DateTime.UtcNow;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            // Reassignment logic: Find member with lowest karma to do it
            var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(occurrence.Chore.HouseId, cancellationToken);
            var eligibleMembers = members.Where(m => m.UserId != userId).ToList();

            if (eligibleMembers.Any())
            {
                var assignee = eligibleMembers
                    .OrderBy(m => m.KarmaBalance)
                    .ThenBy(x => Guid.NewGuid())
                    .First();

                occurrence.AssignedUserId = assignee.UserId;
                occurrence.Status = ChoreOccurrenceStatus.ASSIGNED;
                occurrence.IsForcedReassigned = true;
            }

            _unitOfWork.ChoreOccurrences.Update(occurrence);
            _unitOfWork.RewardRedemptions.Update(redemption);
            
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
