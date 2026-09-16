using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IKarmaTransactionRepository
{
    Task<KarmaTransaction?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<KarmaTransaction>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<KarmaTransaction>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task<IEnumerable<KarmaTransaction>> GetByReferenceIdAndTypeAsync(Guid referenceId, KarmaTransactionType type, CancellationToken cancellationToken = default);
    Task AddAsync(KarmaTransaction transaction, CancellationToken cancellationToken = default);
}
