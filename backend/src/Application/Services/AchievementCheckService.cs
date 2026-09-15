using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Application.Services;

public class AchievementCheckService : IAchievementCheckService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<AchievementCheckService> _logger;

    public AchievementCheckService(IUnitOfWork unitOfWork, ILogger<AchievementCheckService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task CheckAchievementsAsync(Guid houseId, Guid userId, AchievementConditionType conditionType, CancellationToken cancellationToken = default)
    {
        var achievements = await _unitOfWork.Achievements.GetByHouseIdAsync(houseId, cancellationToken);
        var targetAchievements = achievements.Where(a => a.ConditionType == conditionType).ToList();
        
        if (!targetAchievements.Any()) return;

        var existingUserAchievements = await _unitOfWork.UserAchievements.GetByUserIdAsync(userId, cancellationToken);
        var unlockedIds = existingUserAchievements.Select(ua => ua.AchievementId).ToHashSet();

        // Evaluate metric based on condition type
        int currentMetric = await CalculateMetricAsync(userId, conditionType, cancellationToken);

        foreach (var achievement in targetAchievements)
        {
            if (unlockedIds.Contains(achievement.Id)) continue; // already unlocked

            if (currentMetric >= achievement.Threshold)
            {
                var newUnlock = new UserAchievement
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    AchievementId = achievement.Id,
                    UnlockedAt = DateTime.UtcNow
                };
                await _unitOfWork.UserAchievements.AddAsync(newUnlock, cancellationToken);
                await _unitOfWork.SaveChangesAsync(cancellationToken);
                _logger.LogInformation($"User {userId} unlocked achievement {achievement.Name}");
                
                // (Optional) We could publish an AchievementUnlockedEvent here if needed for notifications
            }
        }
    }

    private async Task<int> CalculateMetricAsync(Guid userId, AchievementConditionType conditionType, CancellationToken cancellationToken)
    {
        switch (conditionType)
        {
            case AchievementConditionType.CHORES_COMPLETED:
                var chores = await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(userId, cancellationToken);
                return chores.Count(c => c.Status == ChoreOccurrenceStatus.COMPLETED);
                
            case AchievementConditionType.KARMA_EARNED:
                // For simplicity, we just count the sum of positive transactions 
                // Currently no repository method for getting all KarmaTransactions by user, so return a placeholder.
                // In a real app we'd query: await _unitOfWork.KarmaTransactions.GetByUserIdAsync(...)
                return 0; 
                
            case AchievementConditionType.BOUNTIES_CLAIMED:
                // Placeholder
                return 0;
                
            case AchievementConditionType.STREAK_DAYS:
                // Placeholder
                return 0;
                
            default:
                return 0;
        }
    }
}
