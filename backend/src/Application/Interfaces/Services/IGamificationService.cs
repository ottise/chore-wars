using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Gamification;

namespace ChoreWars.Application.Interfaces.Services;

public interface IGamificationService
{
    Task<int> GetKarmaBalanceAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<RewardResponse>> GetSeasonRewardsAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task ClaimRewardAsync(Guid redemptionId, Guid userId, CancellationToken cancellationToken = default);
    Task UseChorePassAsync(Guid redemptionId, Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<AchievementResponse>> GetAchievementsAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
}
