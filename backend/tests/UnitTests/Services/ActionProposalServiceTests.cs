using System.Text.Json;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public class ActionProposalServiceTests
{
    [Fact]
    public async Task CreateProposalAsync_ShouldCreatePendingConfirmationsForTargets()
    {
        var fixture = new Fixture();
        var targetA = Guid.NewGuid();
        var targetB = Guid.NewGuid();
        fixture.ActiveMember(targetA);
        fixture.ActiveMember(targetB);
        ActionProposal? added = null;
        fixture.Proposals.Setup(x => x.AddAsync(It.IsAny<ActionProposal>(), It.IsAny<CancellationToken>()))
            .Callback<ActionProposal, CancellationToken>((proposal, _) => added = proposal)
            .Returns(Task.CompletedTask);

        var response = await fixture.Service.CreateProposalAsync(fixture.HouseId, new CreateProposalRequest
        {
            Type = ProposalType.SEASON_APPROVAL,
            Title = "Review season",
            PayloadJson = "{}",
            TargetUserIds = new() { targetA, targetB }
        }, fixture.CreatorId);

        Assert.NotNull(added);
        Assert.Equal(ProposalStatus.PENDING, response.Status);
        Assert.Equal(2, response.Confirmations.Count);
        Assert.All(response.Confirmations, x => Assert.Equal(ConfirmationStatus.PENDING, x.Status));
        fixture.UnitOfWork.Verify(x => x.CommitTransactionAsync(It.IsAny<CancellationToken>()), Times.Once);
        fixture.Realtime.Verify(x => x.ProposalCreatedAsync(It.IsAny<ActionProposalResponse>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RespondProposalAsync_WhenTargetRejects_ShouldMarkProposalRejected()
    {
        var fixture = new Fixture();
        var targetId = Guid.NewGuid();
        var proposal = fixture.PendingProposal(targetId, ProposalType.SEASON_APPROVAL, "{}");
        fixture.Proposals.Setup(x => x.GetByIdForUpdateAsync(proposal.Id, It.IsAny<CancellationToken>())).ReturnsAsync(proposal);

        var response = await fixture.Service.RespondProposalAsync(proposal.Id, new RespondProposalRequest
        {
            Status = ConfirmationStatus.REJECTED,
            Reason = "Needs changes"
        }, targetId);

        Assert.Equal(ProposalStatus.REJECTED, response.Status);
        Assert.Equal(ConfirmationStatus.REJECTED, response.Confirmations.Single().Status);
        Assert.Equal("Needs changes", response.Confirmations.Single().Reason);
        fixture.Realtime.Verify(x => x.ProposalUpdatedAsync(It.IsAny<ActionProposalResponse>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RespondProposalAsync_WhenAllTargetsConfirm_ShouldSwapChoreAssigneesAtomically()
    {
        var fixture = new Fixture();
        var targetId = Guid.NewGuid();
        var sourceId = Guid.NewGuid();
        var targetOccurrenceId = Guid.NewGuid();
        var payload = JsonSerializer.Serialize(new ChoreSwapPayload
        {
            SourceOccurrenceId = sourceId,
            TargetOccurrenceId = targetOccurrenceId
        });
        var proposal = fixture.PendingProposal(targetId, ProposalType.CHORE_SWAP, payload);
        var source = fixture.Occurrence(sourceId, fixture.CreatorId);
        var target = fixture.Occurrence(targetOccurrenceId, targetId);
        fixture.Proposals.Setup(x => x.GetByIdForUpdateAsync(proposal.Id, It.IsAny<CancellationToken>())).ReturnsAsync(proposal);
        fixture.Occurrences.Setup(x => x.GetByIdAsync(sourceId, It.IsAny<CancellationToken>())).ReturnsAsync(source);
        fixture.Occurrences.Setup(x => x.GetByIdAsync(targetOccurrenceId, It.IsAny<CancellationToken>())).ReturnsAsync(target);

        var response = await fixture.Service.RespondProposalAsync(proposal.Id, new RespondProposalRequest
        {
            Status = ConfirmationStatus.CONFIRMED
        }, targetId);

        Assert.Equal(ProposalStatus.APPROVED, response.Status);
        Assert.Equal(targetId, source.AssignedUserId);
        Assert.Equal(fixture.CreatorId, target.AssignedUserId);
        fixture.Occurrences.Verify(x => x.Update(source), Times.Once);
        fixture.Occurrences.Verify(x => x.Update(target), Times.Once);
        fixture.UnitOfWork.Verify(x => x.CommitTransactionAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RespondProposalAsync_WhenAllTargetsConfirm_ShouldCreateUrgentChores()
    {
        var fixture = new Fixture();
        var targetId = Guid.NewGuid();
        var seasonId = Guid.NewGuid();
        var payload = JsonSerializer.Serialize(new UrgentEventPayload
        {
            SeasonId = seasonId,
            DeadlineMinutes = 30,
            Chores = new List<UrgentChoreItem>
            {
                new() { Name = "Clean table", AssignedUserId = fixture.CreatorId, KarmaPoints = 10 },
                new() { Name = "Vacuum", AssignedUserId = targetId, KarmaPoints = 20 }
            }
        });
        var proposal = fixture.PendingProposal(targetId, ProposalType.URGENT_EVENT, payload);
        fixture.Proposals.Setup(x => x.GetByIdForUpdateAsync(proposal.Id, It.IsAny<CancellationToken>())).ReturnsAsync(proposal);
        var chores = new List<Chore>();
        var occurrences = new List<ChoreOccurrence>();
        fixture.Chores.Setup(x => x.AddAsync(It.IsAny<Chore>(), It.IsAny<CancellationToken>()))
            .Callback<Chore, CancellationToken>((chore, _) => chores.Add(chore))
            .Returns(Task.CompletedTask);
        fixture.Occurrences.Setup(x => x.AddAsync(It.IsAny<ChoreOccurrence>(), It.IsAny<CancellationToken>()))
            .Callback<ChoreOccurrence, CancellationToken>((occurrence, _) => occurrences.Add(occurrence))
            .Returns(Task.CompletedTask);

        var before = DateTime.UtcNow.AddMinutes(29);
        var response = await fixture.Service.RespondProposalAsync(proposal.Id, new RespondProposalRequest
        {
            Status = ConfirmationStatus.CONFIRMED
        }, targetId);

        Assert.Equal(ProposalStatus.APPROVED, response.Status);
        Assert.Equal(2, chores.Count);
        Assert.Equal(2, occurrences.Count);
        Assert.All(occurrences, x =>
        {
            Assert.Equal(seasonId, x.SeasonId);
            Assert.True(x.DueDate >= before);
            Assert.Equal(ChoreOccurrenceStatus.ASSIGNED, x.Status);
        });
    }

    [Fact]
    public async Task RespondProposalAsync_WhenNonTargetResponds_ShouldThrowForbiddenException()
    {
        var fixture = new Fixture();
        var proposal = fixture.PendingProposal(Guid.NewGuid(), ProposalType.SEASON_APPROVAL, "{}");
        fixture.Proposals.Setup(x => x.GetByIdForUpdateAsync(proposal.Id, It.IsAny<CancellationToken>())).ReturnsAsync(proposal);

        await Assert.ThrowsAsync<ForbiddenException>(() => fixture.Service.RespondProposalAsync(
            proposal.Id,
            new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED },
            Guid.NewGuid()));

        fixture.UnitOfWork.Verify(x => x.RollbackTransactionAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    private sealed class Fixture
    {
        public Guid HouseId { get; } = Guid.NewGuid();
        public Guid RoomId { get; } = Guid.NewGuid();
        public Guid CreatorId { get; } = Guid.NewGuid();
        public Mock<IUnitOfWork> UnitOfWork { get; } = new();
        public Mock<IActionProposalRepository> Proposals { get; } = new();
        public Mock<IHouseMemberRepository> Members { get; } = new();
        public Mock<IChatRepository> Chats { get; } = new();
        public Mock<IChoreOccurrenceRepository> Occurrences { get; } = new();
        public Mock<IChoreRepository> Chores { get; } = new();
        public Mock<IChoreSeasonRepository> Seasons { get; } = new();
        public Mock<IActionProposalRealtimePublisher> Realtime { get; } = new();
        public ActionProposalService Service { get; }

        public Fixture()
        {
            UnitOfWork.SetupGet(x => x.ActionProposals).Returns(Proposals.Object);
            UnitOfWork.SetupGet(x => x.HouseMembers).Returns(Members.Object);
            UnitOfWork.SetupGet(x => x.Chats).Returns(Chats.Object);
            UnitOfWork.SetupGet(x => x.ChoreOccurrences).Returns(Occurrences.Object);
            UnitOfWork.SetupGet(x => x.Chores).Returns(Chores.Object);
            UnitOfWork.SetupGet(x => x.Seasons).Returns(Seasons.Object);
            UnitOfWork.Setup(x => x.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            UnitOfWork.Setup(x => x.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            UnitOfWork.Setup(x => x.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            UnitOfWork.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
            Realtime.Setup(x => x.ProposalCreatedAsync(It.IsAny<ActionProposalResponse>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            Realtime.Setup(x => x.ProposalUpdatedAsync(It.IsAny<ActionProposalResponse>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            Chats.Setup(x => x.GetRoomByHouseIdAsync(HouseId, It.IsAny<CancellationToken>()))
                .ReturnsAsync(new ChatRoom { Id = RoomId, HouseId = HouseId });
            ActiveMember(CreatorId);
            Service = new ActionProposalService(UnitOfWork.Object, Realtime.Object, mutationsEnabled: true);
        }

        public void ActiveMember(Guid userId) => Members
            .Setup(x => x.GetByHouseAndUserIdAsync(HouseId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember { HouseId = HouseId, UserId = userId, Status = HouseMemberStatus.ACTIVE });

        public ActionProposal PendingProposal(Guid targetId, ProposalType type, string payload) => new()
        {
            Id = Guid.NewGuid(),
            HouseId = HouseId,
            RoomId = RoomId,
            CreatorId = CreatorId,
            Type = type,
            Status = ProposalStatus.PENDING,
            Title = "Proposal",
            PayloadJson = payload,
            Confirmations = new List<ProposalConfirmation>
            {
                new() { Id = Guid.NewGuid(), TargetUserId = targetId, Status = ConfirmationStatus.PENDING }
            }
        };

        public ChoreOccurrence Occurrence(Guid id, Guid assignedUserId) => new()
        {
            Id = id,
            AssignedUserId = assignedUserId,
            Chore = new Chore { HouseId = HouseId }
        };
    }
}
