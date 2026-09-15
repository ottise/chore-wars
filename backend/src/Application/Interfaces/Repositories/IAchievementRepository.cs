using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IAchievementRepository
{
    Task<Achievement?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<Achievement>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task AddAsync(Achievement achievement, CancellationToken cancellationToken = default);
    void Update(Achievement achievement);
    void Delete(Achievement achievement);
}
