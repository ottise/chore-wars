using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Moq;
using Xunit;

namespace UnitTests.Services;

public class SeasonConfirmationLockTests
{
    private readonly Mock<IUnitOfWork> _mockUnitOfWork;
    private readonly Mock<IMapper> _mockMapper;
    private readonly Mock<IChoreGenerationService> _mockGenerationService;
    private readonly Mock<IChoreAllocationService> _mockAllocationService;
    private readonly Mock<IChoreOccurrenceRepository> _mockChoreOccurrences;
    private readonly SeasonService _service;

    public SeasonConfirmationLockTests()
    {
        _mockUnitOfWork = new Mock<IUnitOfWork>();
        _mockMapper = new Mock<IMapper>();
        _mockGenerationService = new Mock<IChoreGenerationService>();
        _mockAllocationService = new Mock<IChoreAllocationService>();
        _mockChoreOccurrences = new Mock<IChoreOccurrenceRepository>();

        _mockUnitOfWork.SetupGet(u => u.ChoreOccurrences).Returns(_mockChoreOccurrences.Object);
        _mockChoreOccurrences
            .Setup(repository => repository.DeleteBySeasonIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _mockUnitOfWork.Setup(u => u.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        _service = new SeasonService(
            _mockUnitOfWork.Object,
            _mockMapper.Object,
            _mockGenerationService.Object,
            _mockAllocationService.Object
        );
    }

    [Fact]
    public async Task ConfirmSeasonAsync_WhenPartialConfirmed_ShouldStayReviewing()
    {
        // Arrange
        var seasonId = Guid.NewGuid();
        var userA = Guid.NewGuid();
        var userB = Guid.NewGuid();

        var season = new ChoreSeason
        {
            Id = seasonId,
            Status = SeasonStatus.REVIEWING
        };

        var confA = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = userA, Status = ConfirmationStatus.PENDING };
        var confB = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = userB, Status = ConfirmationStatus.PENDING };
        var confC = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = Guid.NewGuid(), Status = confA.Status };
        var allConfirmations = new List<SeasonConfirmation> { confA, confB, confC };
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(season.HouseId, It.IsAny<CancellationToken>())).ReturnsAsync(allConfirmations.Select(c => new HouseMember { HouseId = season.HouseId, UserId = c.UserId, Status = HouseMemberStatus.ACTIVE }));

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userA, It.IsAny<CancellationToken>())).ReturnsAsync(confA);
        _mockUnitOfWork.Setup(u => u.SeasonConfirmations.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(allConfirmations);

        // Act
        await _service.ConfirmSeasonAsync(seasonId, userA, expectedRevision: season.ScheduleRevision);

        // Assert
        Assert.Equal(ConfirmationStatus.CONFIRMED, confA.Status);
        Assert.Equal(SeasonStatus.REVIEWING, season.Status);
    }

    [Fact]
    public async Task ConfirmSeasonAsync_WhenAllConfirmed_ShouldBecomeActive()
    {
        // Arrange
        var seasonId = Guid.NewGuid();
        var userA = Guid.NewGuid();
        var userB = Guid.NewGuid();

        var season = new ChoreSeason
        {
            Id = seasonId,
            Status = SeasonStatus.REVIEWING
        };

        var confA = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = userA, Status = ConfirmationStatus.CONFIRMED };
        var confB = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = userB, Status = ConfirmationStatus.PENDING };
        var confC = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = Guid.NewGuid(), Status = confA.Status };
        var allConfirmations = new List<SeasonConfirmation> { confA, confB, confC };
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(season.HouseId, It.IsAny<CancellationToken>())).ReturnsAsync(allConfirmations.Select(c => new HouseMember { HouseId = season.HouseId, UserId = c.UserId, Status = HouseMemberStatus.ACTIVE }));

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userB, It.IsAny<CancellationToken>())).ReturnsAsync(confB);
        _mockUnitOfWork.Setup(u => u.SeasonConfirmations.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(allConfirmations);

        // Act
        await _service.ConfirmSeasonAsync(seasonId, userB, expectedRevision: season.ScheduleRevision);

        // Assert
        Assert.Equal(ConfirmationStatus.CONFIRMED, confB.Status);
        Assert.Equal(SeasonStatus.ACTIVE, season.Status);
        _mockUnitOfWork.Verify(u => u.Seasons.Update(season), Times.Once);
    }

    [Fact]
    public async Task RejectSeasonAsync_WhenOneRejects_ShouldDiscardScheduleAndRollbackToDraft()
    {
        // Arrange
        var seasonId = Guid.NewGuid();
        var userA = Guid.NewGuid();

        var season = new ChoreSeason
        {
            Id = seasonId,
            Status = SeasonStatus.REVIEWING
        };

        var confA = new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = userA, Status = ConfirmationStatus.PENDING };

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userA, It.IsAny<CancellationToken>())).ReturnsAsync(confA);

        // Act
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userA, It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember { UserId = userA, Status = HouseMemberStatus.ACTIVE });
        await _service.RejectSeasonAsync(seasonId, userA, reason: "Please rebalance the schedule.");

        // Assert
        Assert.Equal(SeasonStatus.DRAFT, season.Status);
        _mockUnitOfWork.Verify(u => u.Seasons.Update(season), Times.Once);
        _mockUnitOfWork.Verify(
            u => u.SeasonConfirmations.DeleteBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>()),
            Times.Once);
        _mockChoreOccurrences.Verify(
            repository => repository.DeleteBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>()),
            Times.Once);
    }
}
