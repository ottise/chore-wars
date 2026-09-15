using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IChoreBountyRepository
{
    Task<ChoreBounty?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<ChoreBounty?> GetByOccurrenceIdAsync(Guid occurrenceId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreBounty>> GetActiveBountiesByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreBounty>> GetExpiredEligibleBountiesAsync(DateTime now, CancellationToken cancellationToken = default);
    Task AddAsync(ChoreBounty bounty, CancellationToken cancellationToken = default);
    void Update(ChoreBounty bounty);
}
