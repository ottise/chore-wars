using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChoreFrequencyDayRepository
{
    Task<IEnumerable<ChoreFrequencyDay>> GetByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default);
    Task DeleteByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default);
    Task AddAsync(ChoreFrequencyDay entity, CancellationToken cancellationToken = default);
}
