using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IActionProposalRepository
{
    Task<ActionProposal?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<ActionProposal?> GetByIdForUpdateAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ActionProposal>> GetActiveByRoomIdAsync(Guid roomId, DateTime now, CancellationToken cancellationToken = default);
    Task AddAsync(ActionProposal proposal, CancellationToken cancellationToken = default);
    void Update(ActionProposal proposal);
}
