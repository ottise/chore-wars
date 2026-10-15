using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
using Moq;

namespace UnitTests.Services;

public class BountyCompensationTests
{
    [Fact]
    public async Task ExpiredBounty_ShouldCreateForcedCompensationAt120Percent()
    {
        var houseId = Guid.NewGuid();
        var posterId = Guid.NewGuid();
        var assigneeId = Guid.NewGuid();
        var occurrence = new ChoreOccurrence
        {
            Id = Guid.NewGuid(),
            AssignedUserId = posterId,
            Chore = new Chore { HouseId = houseId }
        };
        var bounty = new ChoreBounty
        {
            Id = Guid.NewGuid(),
            ChoreOccurrenceId = occurrence.Id,
            PostedByUserId = posterId,
            Amount = 100m,
            Status = BountyStatus.OPEN,
            ChoreOccurrence = occurrence
        };

        var unitOfWork = new Mock<IUnitOfWork>();
        var bounties = new Mock<IChoreBountyRepository>();
        var members = new Mock<IHouseMemberRepository>();
        var occurrences = new Mock<IChoreOccurrenceRepository>();
        var payments = new Mock<IPaymentObligationRepository>();
        PaymentObligation? captured = null;
        unitOfWork.SetupGet(x => x.ChoreBounties).Returns(bounties.Object);
        unitOfWork.SetupGet(x => x.HouseMembers).Returns(members.Object);
        unitOfWork.SetupGet(x => x.ChoreOccurrences).Returns(occurrences.Object);
        unitOfWork.SetupGet(x => x.PaymentObligations).Returns(payments.Object);
        unitOfWork.Setup(x => x.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(x => x.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(x => x.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
        bounties.Setup(x => x.GetExpiredEligibleBountiesAsync(It.IsAny<DateTime>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { bounty });
        members.Setup(x => x.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[]
            {
                new HouseMember { UserId = posterId, KarmaBalance = 10 },
                new HouseMember { UserId = assigneeId, KarmaBalance = 0 }
            });
        occurrences.Setup(x => x.GetByIdAsync(occurrence.Id, It.IsAny<CancellationToken>())).ReturnsAsync(occurrence);
        payments.Setup(x => x.AddAsync(It.IsAny<PaymentObligation>(), It.IsAny<CancellationToken>()))
            .Callback<PaymentObligation, CancellationToken>((payment, _) => captured = payment)
            .Returns(Task.CompletedTask);
        var events = new Mock<IEventPublisher>();
        events.Setup(x => x.PublishAsync(It.IsAny<object>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        var service = new BountyExpirationService(unitOfWork.Object, Mock.Of<ILogger<BountyExpirationService>>(), events.Object);

        await service.ProcessExpiredBountiesAsync();

        Assert.Equal(BountyStatus.EXPIRED, bounty.Status);
        Assert.Equal(assigneeId, occurrence.AssignedUserId);
        Assert.NotNull(captured);
        Assert.Equal(100m * BountyConstants.ForcedReassignmentMultiplier, captured.Amount);
        Assert.Equal(occurrence.Id, captured.OccurrenceId);
        Assert.Equal(PaymentObligationReason.FORCED_REASSIGNMENT, captured.Reason);
    }
}
