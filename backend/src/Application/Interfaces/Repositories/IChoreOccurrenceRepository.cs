using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChoreOccurrenceRepository
{
    Task<ChoreOccurrence?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreOccurrence>> GetByAssignedUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreOccurrence>> GetByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreOccurrence>> GetOverdueEligibleOccurrencesAsync(DateTime now, CancellationToken cancellationToken = default);
    Task AddAsync(ChoreOccurrence occurrence, CancellationToken cancellationToken = default);
    void Update(ChoreOccurrence occurrence);
    void Delete(ChoreOccurrence occurrence);
}
