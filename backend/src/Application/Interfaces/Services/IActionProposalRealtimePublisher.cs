using ChoreWars.Application.DTOs.Proposal;

namespace ChoreWars.Application.Interfaces.Services;

public interface IActionProposalRealtimePublisher
{
    Task ProposalCreatedAsync(ActionProposalResponse proposal, CancellationToken cancellationToken = default);
    Task ProposalUpdatedAsync(ActionProposalResponse proposal, CancellationToken cancellationToken = default);
}
