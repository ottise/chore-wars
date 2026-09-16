using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface ISeasonConfirmationRepository
{
    Task<SeasonConfirmation?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<SeasonConfirmation>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    Task<SeasonConfirmation?> GetBySeasonAndUserIdAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(SeasonConfirmation confirmation, CancellationToken cancellationToken = default);
    Task DeleteBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default);
    void Update(SeasonConfirmation confirmation);
    void Delete(SeasonConfirmation confirmation);
}
