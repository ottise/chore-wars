using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IMemberAvailabilityRepository
{
    Task<MemberAvailability?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<MemberAvailability>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task<IEnumerable<MemberAvailability>> GetBySeasonAndUserIdAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(MemberAvailability availability, CancellationToken cancellationToken = default);
    void Update(MemberAvailability availability);
    void Delete(MemberAvailability availability);
}
