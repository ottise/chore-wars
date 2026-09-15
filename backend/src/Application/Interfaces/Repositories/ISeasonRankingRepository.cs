using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface ISeasonRankingRepository
{
    Task<SeasonRanking?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<SeasonRanking?> GetBySeasonAndUserIdAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<SeasonRanking>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task AddAsync(SeasonRanking ranking, CancellationToken cancellationToken = default);
    void Update(SeasonRanking ranking);
}
