using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IRewardRedemptionRepository
{
    Task<RewardRedemption?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<RewardRedemption>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<RewardRedemption?> GetByRewardAndUserIdAsync(Guid rewardId, Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(RewardRedemption redemption, CancellationToken cancellationToken = default);
    void Update(RewardRedemption redemption);
}
