using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.SignalR;

namespace ChoreWars.Presentation.Hubs;

public class ActionProposalRealtimePublisher : IActionProposalRealtimePublisher
{
    private readonly IHubContext<ChatHub> _hubContext;

    public ActionProposalRealtimePublisher(IHubContext<ChatHub> hubContext) => _hubContext = hubContext;

    public Task ProposalCreatedAsync(ActionProposalResponse proposal, CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Group(ChatHub.RoomGroup(proposal.RoomId))
            .SendAsync("ReceiveProposal", proposal, cancellationToken);

    public Task ProposalUpdatedAsync(ActionProposalResponse proposal, CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Group(ChatHub.RoomGroup(proposal.RoomId))
            .SendAsync("ProposalUpdated", proposal, cancellationToken);
}
