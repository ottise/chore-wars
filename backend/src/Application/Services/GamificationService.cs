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
        var summary = await GetKarmaSummaryAsync(houseId, userId, cancellationToken);
        return summary.Current;
    }

    public async Task<KarmaSummaryResponse> GetKarmaSummaryAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var activeSeason = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason == null)
            return new KarmaSummaryResponse();

        var transactions = (await _unitOfWork.KarmaTransactions.GetByUserIdAsync(userId, cancellationToken))
            .Where(item => item.HouseId == houseId && item.SeasonId == activeSeason.Id)
            .ToList();

        return new KarmaSummaryResponse
        {
            Current = transactions.Sum(item => item.Amount),
            NormalChores = transactions
                .Where(item => item.Type == KarmaTransactionType.CHORE_COMPLETED)
                .Sum(item => item.Amount),
            Bonus = transactions
                .Where(item => item.Type is KarmaTransactionType.BONUS or KarmaTransactionType.BOUNTY_REWARD)
                .Sum(item => item.Amount),
            Penalties = transactions
                .Where(item => item.Type == KarmaTransactionType.PENALTY)
                .Sum(item => item.Amount)
        };
    }

    public async Task<IEnumerable<KarmaTransactionResponse>> GetKarmaHistoryAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var transactions = await _unitOfWork.KarmaTransactions.GetByUserIdAsync(userId, cancellationToken);
        return transactions
            .Where(item => item.HouseId == houseId)
            .Select(item => new KarmaTransactionResponse
            {
                Id = item.Id,
                Amount = item.Amount,
                Type = item.Type,
                Description = item.Type switch
                {
                    KarmaTransactionType.CHORE_COMPLETED => "Chore completed",
                    KarmaTransactionType.PENALTY => "Overdue penalty",
                    KarmaTransactionType.BOUNTY_REWARD => "Bounty reward",
                    KarmaTransactionType.REWARD_REDEEMED => "Reward redeemed",
                    KarmaTransactionType.BONUS => "Bonus chore",
                    _ => "Karma update"
                },
                CreatedAt = item.CreatedAt
            });
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
        var response = new List<RewardResponse>();
        foreach (var reward in rewards)
        {
            var redemption = await _unitOfWork.RewardRedemptions.GetByRewardAndUserIdAsync(
                reward.Id,
                userId,
                cancellationToken);
            if (redemption == null)
                continue;

            var status = redemption.Status;
            if (status == RewardRedemptionStatus.UNCLAIMED &&
                redemption.ClaimDeadline.HasValue &&
                redemption.ClaimDeadline.Value < DateTime.UtcNow)
                status = RewardRedemptionStatus.EXPIRED;
            if (status == RewardRedemptionStatus.CLAIMED &&
                redemption.UsageDeadline.HasValue &&
                redemption.UsageDeadline.Value < DateTime.UtcNow)
                status = RewardRedemptionStatus.EXPIRED;

            var rewardResponse = _mapper.Map<RewardResponse>(reward);
            rewardResponse.RedemptionId = redemption.Id;
            rewardResponse.Status = status;
            rewardResponse.ClaimDeadline = redemption.ClaimDeadline;
            rewardResponse.UsageDeadline = redemption.UsageDeadline;
            response.Add(rewardResponse);
        }
        return response;
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
        redemption.RedeemedAt = DateTime.UtcNow;
        redemption.UsageDeadline = DateTime.UtcNow.AddDays(10);
        
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

        if (redemption.UsageDeadline.HasValue && redemption.UsageDeadline.Value < DateTime.UtcNow)
        {
            redemption.Status = RewardRedemptionStatus.EXPIRED;
            _unitOfWork.RewardRedemptions.Update(redemption);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            throw new ConflictException("Chore pass has expired");
        }

        var reward = await _unitOfWork.Rewards.GetByIdAsync(redemption.RewardId, cancellationToken);
        if (reward == null || reward.Type != RewardType.CHORE_PASS)
            throw new ConflictException("Invalid reward or not a chore pass.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException("ChoreOccurrence not found");

        if (occurrence.AssignedUserId != userId)
            throw new ForbiddenException("Can only skip your own chore.");

        if (occurrence.Status != ChoreOccurrenceStatus.ASSIGNED)
            throw new ConflictException("Only a pending chore can be covered by a Chore Pass.");
        
        var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(occurrence.Chore.HouseId, cancellationToken);
        var eligibleMembers = members.Where(m => m.UserId != userId).ToList();
        if (!eligibleMembers.Any())
            throw new ConflictException("No eligible house member is available to cover this chore.");

        var assignee = eligibleMembers
            .OrderBy(m => m.KarmaBalance)
            .ThenBy(x => Guid.NewGuid())
            .First();

        occurrence.AssignedUserId = assignee.UserId;
        occurrence.Status = ChoreOccurrenceStatus.ASSIGNED;
        occurrence.IsForcedReassigned = true;
        redemption.Status = RewardRedemptionStatus.USED;
        redemption.UsedAt = DateTime.UtcNow;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
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
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var achievements = await _unitOfWork.Achievements.GetByHouseIdAsync(houseId, cancellationToken);
        var unlocked = (await _unitOfWork.UserAchievements.GetByUserIdAsync(userId, cancellationToken))
            .ToDictionary(item => item.AchievementId, item => item.UnlockedAt);
        return achievements.Select(item =>
        {
            var response = _mapper.Map<AchievementResponse>(item);
            response.IsUnlocked = unlocked.ContainsKey(item.Id);
            response.UnlockedAt = unlocked.GetValueOrDefault(item.Id);
            return response;
        });
    }
}
