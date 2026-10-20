using AutoMapper;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public class ChoreAssignmentTests
{
    private static (ChoreService Service, Mock<IUnitOfWork> Uow, Chore Chore, ChoreSeason Season, Guid User) Setup()
    {
        var user = Guid.NewGuid();
        var season = new ChoreSeason { Id = Guid.NewGuid(), HouseId = Guid.NewGuid(), Status = SeasonStatus.DRAFT, ScheduleRevision = 2 };
        var chore = new Chore { Id = Guid.NewGuid(), HouseId = season.HouseId, SeasonId = season.Id, Type = ChoreType.NORMAL };
        var uow = new Mock<IUnitOfWork>();
        uow.Setup(x => x.Chores.GetByIdAsync(chore.Id,It.IsAny<CancellationToken>())).ReturnsAsync(chore);
        uow.Setup(x => x.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId,user,It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember { UserId = user, Status = HouseMemberStatus.ACTIVE, Role = HouseRole.OWNER });
        uow.Setup(x => x.Seasons.GetCurrentSeasonByHouseIdAsync(chore.HouseId,It.IsAny<CancellationToken>())).ReturnsAsync(season);
        return (new ChoreService(uow.Object,Mock.Of<IMapper>(),Mock.Of<IEventPublisher>(),Mock.Of<IKarmaService>()),uow,chore,season,user);
    }

    [Fact] public async Task LegacyAssignCannotInventAnOccurrenceOutsideTheGeneratedCalendar()
    {
        var f = Setup();
        await Assert.ThrowsAsync<ConflictException>(() => f.Service.AssignChoreAsync(f.Chore.Id,new AssignChoreRequest { UserId = f.User },f.User));
        f.Uow.Verify(x => x.ChoreOccurrences.AddAsync(It.IsAny<ChoreOccurrence>(),It.IsAny<CancellationToken>()),Times.Never);
        Assert.Equal(2,f.Season.ScheduleRevision);
    }

    [Fact] public async Task AssignUpdatesOnlyTheSelectedOccurrenceAndScheduleRevision()
    {
        var f = Setup();
        var due = DateTime.UtcNow.AddDays(1);
        var occurrence = new ChoreOccurrence { Id = Guid.NewGuid(), ChoreId = f.Chore.Id, SeasonId = f.Season.Id, DueDate = due, SnapshotKarma = 35 };
        f.Uow.Setup(x => x.ChoreOccurrences.GetByIdAsync(occurrence.Id,It.IsAny<CancellationToken>())).ReturnsAsync(occurrence);
        await f.Service.AssignChoreAsync(f.Chore.Id,new AssignChoreRequest { UserId = f.User, OccurrenceId = occurrence.Id },f.User);
        Assert.Equal(f.User,occurrence.AssignedUserId);
        Assert.Equal(due,occurrence.DueDate); Assert.Equal(35,occurrence.SnapshotKarma);
        Assert.Equal(3,f.Season.ScheduleRevision);
    }
}
