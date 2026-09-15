using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChoreRepository
{
    Task<Chore?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<Chore>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<IEnumerable<Chore>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task AddAsync(Chore chore, CancellationToken cancellationToken = default);
    void Update(Chore chore);
    void Delete(Chore chore);
}
