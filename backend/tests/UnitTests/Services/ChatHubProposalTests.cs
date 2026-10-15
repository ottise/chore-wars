using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Presentation.Hubs;
using Microsoft.AspNetCore.SignalR;
using Moq;

namespace UnitTests.Services;

public class ChatHubProposalTests
{
    [Theory]
    [InlineData(true, "ReceiveProposal")]
    [InlineData(false, "ProposalUpdated")]
    public async Task ProposalBroadcast_ShouldTargetCorrectRoomGroup(bool created, string eventName)
    {
        var roomId = Guid.NewGuid();
        var proxy = new Mock<IClientProxy>();
        proxy.Setup(x => x.SendCoreAsync(It.IsAny<string>(), It.IsAny<object?[]>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var clients = new Mock<IHubClients>();
        clients.Setup(x => x.Group(ChatHub.RoomGroup(roomId))).Returns(proxy.Object);
        var hub = new Mock<IHubContext<ChatHub>>();
        hub.SetupGet(x => x.Clients).Returns(clients.Object);
        var publisher = new ActionProposalRealtimePublisher(hub.Object);
        var proposal = new ActionProposalResponse { Id = Guid.NewGuid(), RoomId = roomId };

        if (created)
            await publisher.ProposalCreatedAsync(proposal);
        else
            await publisher.ProposalUpdatedAsync(proposal);

        clients.Verify(x => x.Group($"room:{roomId}"), Times.Once);
        proxy.Verify(x => x.SendCoreAsync(
            eventName,
            It.Is<object?[]>(args => args.Length == 1 && ReferenceEquals(args[0], proposal)),
            It.IsAny<CancellationToken>()), Times.Once);
    }
}
