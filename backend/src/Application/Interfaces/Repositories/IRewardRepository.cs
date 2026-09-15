using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IRewardRepository
{
    Task<Reward?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<Reward>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task<Reward?> GetChorePassRewardAsync(CancellationToken cancellationToken = default);
    Task AddAsync(Reward reward, CancellationToken cancellationToken = default);
    void Update(Reward reward);
    void Delete(Reward reward);
}
