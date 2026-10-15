using ChoreWars.Application.DTOs.Proposal;

namespace ChoreWars.Application.Interfaces.Services;

public interface IActionProposalService
{
    Task<ActionProposalResponse> CreateProposalAsync(Guid houseId, CreateProposalRequest request, Guid creatorId, CancellationToken cancellationToken = default);
    Task<ActionProposalResponse> RespondProposalAsync(Guid proposalId, RespondProposalRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ActionProposalResponse>> GetActiveProposalsAsync(Guid roomId, Guid userId, CancellationToken cancellationToken = default);
}
