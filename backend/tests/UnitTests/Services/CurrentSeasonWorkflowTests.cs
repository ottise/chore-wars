using AutoMapper;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public class CurrentSeasonWorkflowTests
{
    [Fact]
    public async Task CreateChoreAsync_AddsChoreToDraftSeason()
    {
        var houseId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var season = new ChoreSeason { Id = Guid.NewGuid(), HouseId = houseId, Status = SeasonStatus.DRAFT, StartDate = DateTime.UtcNow.Date, EndDate = DateTime.UtcNow.Date.AddDays(7) };
        var unitOfWork = CreateUnitOfWork();
        var mapper = new Mock<IMapper>();

        unitOfWork.SetupGet(item => item.HouseMembers).Returns(Mock.Of<IHouseMemberRepository>());
        unitOfWork.SetupGet(item => item.Seasons).Returns(Mock.Of<IChoreSeasonRepository>());
        unitOfWork.SetupGet(item => item.Chores).Returns(Mock.Of<IChoreRepository>());
        unitOfWork.SetupGet(item => item.ChoreFrequencyDays).Returns(Mock.Of<IChoreFrequencyDayRepository>());
        unitOfWork.Setup(item => item.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember { HouseId = houseId, UserId = userId, Role = HouseRole.OWNER, Status = HouseMemberStatus.ACTIVE });
        unitOfWork.Setup(item => item.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(season);
        mapper.Setup(item => item.Map<ChoreResponse>(It.IsAny<Chore>()))
            .Returns(new ChoreResponse());

        var service = new ChoreService(
            unitOfWork.Object,
            mapper.Object,
            Mock.Of<IEventPublisher>(),
            Mock.Of<IKarmaService>());

        await service.CreateChoreAsync(houseId, new CreateChoreRequest { Name = "Take out trash" }, userId);

        unitOfWork.Verify(
            item => item.Chores.AddAsync(
                It.Is<Chore>(chore => chore.SeasonId == season.Id && chore.HouseId == houseId),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task CreateChoreAsync_WhenActiveSeasonHasNoFutureDates_ThrowsClearConflict()
    {
        var houseId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var unitOfWork = CreateUnitOfWork();
        unitOfWork.SetupGet(item => item.HouseMembers).Returns(Mock.Of<IHouseMemberRepository>());
        unitOfWork.SetupGet(item => item.Seasons).Returns(Mock.Of<IChoreSeasonRepository>());
        unitOfWork.Setup(item => item.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember { HouseId = houseId, UserId = userId, Role = HouseRole.OWNER, Status = HouseMemberStatus.ACTIVE });
        unitOfWork.Setup(item => item.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ChoreSeason { HouseId = houseId, Status = SeasonStatus.ACTIVE });

        var service = new ChoreService(
            unitOfWork.Object,
            Mock.Of<IMapper>(),
            Mock.Of<IEventPublisher>(),
            Mock.Of<IKarmaService>());

        var exception = await Assert.ThrowsAsync<ConflictException>(() =>
            service.CreateChoreAsync(houseId, new CreateChoreRequest(), userId));

        Assert.Contains("No future chore dates", exception.Message);
    }

    [Fact]
    public async Task CreateSeasonAsync_WhenDraftExists_RejectsDuplicateSeason()
    {
        var houseId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var unitOfWork = CreateUnitOfWork();
        unitOfWork.SetupGet(item => item.HouseMembers).Returns(Mock.Of<IHouseMemberRepository>());
        unitOfWork.SetupGet(item => item.Seasons).Returns(Mock.Of<IChoreSeasonRepository>());
        unitOfWork.Setup(item => item.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember { HouseId = houseId, UserId = userId, Role = HouseRole.OWNER, Status = HouseMemberStatus.ACTIVE });
        unitOfWork.Setup(item => item.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ChoreSeason { HouseId = houseId, Status = SeasonStatus.DRAFT });

        var service = new SeasonService(
            unitOfWork.Object,
            Mock.Of<IMapper>(),
            Mock.Of<IChoreGenerationService>(),
            Mock.Of<IChoreAllocationService>());

        var exception = await Assert.ThrowsAsync<ConflictException>(() =>
            service.CreateSeasonAsync(houseId, new CreateSeasonRequest(), userId));

        Assert.Contains("unfinished season", exception.Message);
    }

    [Fact]
    public async Task GetActiveSeasonAsync_WhenReviewing_ReturnsCurrentUsersConfirmationProgress()
    {
        var houseId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var season = new ChoreSeason
        {
            Id = Guid.NewGuid(),
            HouseId = houseId,
            Status = SeasonStatus.REVIEWING
        };
        var unitOfWork = CreateUnitOfWork();
        var mapper = new Mock<IMapper>();
        var members = new Mock<IHouseMemberRepository>();
        var seasons = new Mock<IChoreSeasonRepository>();
        var confirmations = new Mock<ISeasonConfirmationRepository>();
        unitOfWork.SetupGet(item => item.HouseMembers).Returns(members.Object);
        unitOfWork.SetupGet(item => item.Seasons).Returns(seasons.Object);
        unitOfWork.SetupGet(item => item.SeasonConfirmations).Returns(confirmations.Object);
        members.Setup(item => item.GetByHouseAndUserIdAsync(houseId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember { HouseId = houseId, UserId = userId, Status = HouseMemberStatus.ACTIVE });
        seasons.Setup(item => item.GetCurrentSeasonByHouseIdAsync(houseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(season);
        confirmations.Setup(item => item.GetBySeasonIdAsync(season.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[]
            {
                new SeasonConfirmation
                {
                    SeasonId = season.Id,
                    UserId = userId,
                    Status = ConfirmationStatus.CONFIRMED
                },
                new SeasonConfirmation
                {
                    SeasonId = season.Id,
                    UserId = Guid.NewGuid(),
                    Status = ConfirmationStatus.PENDING
                }
            });
        mapper.Setup(item => item.Map<SeasonResponse>(season)).Returns(new SeasonResponse());

        var service = new SeasonService(
            unitOfWork.Object,
            mapper.Object,
            Mock.Of<IChoreGenerationService>(),
            Mock.Of<IChoreAllocationService>());

        var response = await service.GetActiveSeasonAsync(houseId, userId);

        Assert.NotNull(response);
        Assert.Equal(ConfirmationStatus.CONFIRMED, response.CurrentUserConfirmationStatus);
        Assert.Equal(1, response.ConfirmedCount);
        Assert.Equal(2, response.RequiredConfirmationCount);
    }

    private static Mock<IUnitOfWork> CreateUnitOfWork()
    {
        var unitOfWork = new Mock<IUnitOfWork>();
        unitOfWork.Setup(item => item.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(item => item.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(item => item.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(item => item.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
        unitOfWork.Setup(x => x.Houses.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Guid id, CancellationToken _) => new House { Id = id });
        unitOfWork.Setup(x => x.ChoreOccurrences.HasOccurrencesForSeasonAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(false);
        return unitOfWork;
    }
}
