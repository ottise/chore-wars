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
            SeasonId = Guid.NewGuid(),
            DueDate = DateTime.UtcNow.AddHours(-1),
            Chore = new Chore { HouseId = houseId }
        };
        var bounty = new ChoreBounty
        {
            Id = Guid.NewGuid(),
            ChoreOccurrenceId = occurrence.Id,
            PostedByUserId = posterId,
            Amount = 100m,
            Status = BountyStatus.OPEN,
            ExpiresAt = DateTime.UtcNow.AddMinutes(-1),
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
                new HouseMember { Status = HouseMemberStatus.ACTIVE, UserId = posterId, KarmaBalance = 10 },
                new HouseMember { Status = HouseMemberStatus.ACTIVE, UserId = assigneeId, KarmaBalance = 0 }
            });
        occurrences.Setup(x => x.GetByIdAsync(occurrence.Id, It.IsAny<CancellationToken>())).ReturnsAsync(occurrence);
        payments.Setup(x => x.AddAsync(It.IsAny<PaymentObligation>(), It.IsAny<CancellationToken>()))
            .Callback<PaymentObligation, CancellationToken>((payment, _) => captured = payment)
            .Returns(Task.CompletedTask);
        bounties.Setup(x => x.GetByIdAsync(bounty.Id,It.IsAny<CancellationToken>())).ReturnsAsync(bounty);
        occurrences.Setup(x => x.GetBySeasonIdAsync(occurrence.SeasonId,It.IsAny<CancellationToken>())).ReturnsAsync(new[] { occurrence });
        payments.Setup(x => x.GetByHouseIdAsync(houseId,It.IsAny<CancellationToken>())).ReturnsAsync(Array.Empty<PaymentObligation>());
        unitOfWork.Setup(x => x.MemberAvailabilities.GetBySeasonIdAsync(occurrence.SeasonId,It.IsAny<CancellationToken>())).ReturnsAsync(Enumerable.Range(0,7).Select(day => new MemberAvailability { UserId = assigneeId, DayOfWeek = (DayOfWeek)day, IsAvailable = true }));
        unitOfWork.Setup(x => x.MemberConstraints.GetByUserAndHouseIdAsync(assigneeId,houseId,It.IsAny<CancellationToken>())).ReturnsAsync((MemberConstraint?)null);
        var events = new Mock<IEventPublisher>();
        events.Setup(x => x.PublishAsync(It.IsAny<object>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        var service = new BountyExpirationService(unitOfWork.Object, Mock.Of<ILogger<BountyExpirationService>>(), events.Object);

        var originalDeadline = occurrence.DueDate;
        await service.ProcessExpiredBountiesAsync();

        Assert.Equal(BountyStatus.EXPIRED, bounty.Status);
        Assert.Equal(assigneeId, occurrence.AssignedUserId);
        Assert.NotNull(captured);
        Assert.Equal(100m * BountyConstants.ForcedReassignmentMultiplier, captured.Amount);
        Assert.Equal(occurrence.Id, captured.OccurrenceId);
        Assert.Equal(PaymentObligationReason.FORCED_REASSIGNMENT, captured.Reason);
        var previous = Assert.Single(occurrence.Responsibilities, r => r.EndedAt != null);
        Assert.Equal(originalDeadline, previous.Deadline);
    }
}
