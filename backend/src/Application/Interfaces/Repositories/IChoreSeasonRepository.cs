using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChoreSeasonRepository
{
    Task<ChoreSeason?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreSeason>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<ChoreSeason?> GetActiveSeasonByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreSeason>> GetActiveSeasonsAsync(DateTime now, CancellationToken cancellationToken = default);
    Task AddAsync(ChoreSeason season, CancellationToken cancellationToken = default);
    void Update(ChoreSeason season);
}
