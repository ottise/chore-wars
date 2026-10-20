using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
using Moq;

namespace UnitTests.Services;

public class ResponsibilityPenaltyTests
{
    [Theory]
    [InlineData(11,0)]
    [InlineData(12,1)]
    [InlineData(24,2)]
    [InlineData(80,3)]
    public async Task PenaltiesArePerEpisodeCappedAndSafeToRetry(int hoursOverdue,int expected)
    {
        var now = DateTime.UtcNow;
        var season = new ChoreSeason { Id = Guid.NewGuid(), HouseId = Guid.NewGuid(), StartDate = now.AddDays(-10), EndDate = now.AddDays(2), Status = SeasonStatus.ACTIVE };
        var episode = new ChoreResponsibility { Id = Guid.NewGuid(), UserId = Guid.NewGuid(), Deadline = now.AddHours(-hoursOverdue) };
        var occurrence = new ChoreOccurrence { Id = Guid.NewGuid(), Chore = new Chore { HouseId = season.HouseId }, SeasonId = season.Id, AssignedUserId = episode.UserId, DueDate = episode.Deadline, Status = ChoreOccurrenceStatus.ASSIGNED, Responsibilities = new List<ChoreResponsibility> { episode } };
        var uow = new Mock<IUnitOfWork>();
        uow.Setup(x => x.ChoreOccurrences.GetByIdAsync(occurrence.Id,It.IsAny<CancellationToken>())).ReturnsAsync(occurrence);
        uow.Setup(x => x.Seasons.GetByIdAsync(season.Id,It.IsAny<CancellationToken>())).ReturnsAsync(season);
        var karma = new Mock<IKarmaService>();
        var service = new OverduePenaltyService(uow.Object,Mock.Of<ILogger<OverduePenaltyService>>(),Mock.Of<IEventPublisher>(),karma.Object);
        await service.ApplyUntilAsync(occurrence.Id,now);
        await service.ApplyUntilAsync(occurrence.Id,now);
        Assert.Equal(expected,episode.PenaltiesApplied);
        karma.Verify(x => x.AddKarmaTransactionAsync(season.HouseId,season.Id,episode.UserId,-5,KarmaTransactionType.PENALTY,episode.Id,It.IsAny<CancellationToken>(),now,It.IsAny<int?>()),Times.Exactly(expected));
        Assert.Equal(expected == 3 ? ChoreOccurrenceStatus.CRITICAL_OVERDUE : ChoreOccurrenceStatus.OVERDUE,occurrence.Status);
    }

    [Fact] public async Task TransferKeepsPreviousPenaltiesAndGivesReplacementANewEpisode()
    {
        var now = DateTime.UtcNow;
        var old = new ChoreResponsibility { Id = Guid.NewGuid(), UserId = Guid.NewGuid(), PenaltiesApplied = 3, Deadline = now.AddDays(-2) };
        var occurrence = new ChoreOccurrence { Id = Guid.NewGuid(), AssignedUserId = old.UserId, PenaltyCount = 3, IsForcedReassigned = true, Responsibilities = new List<ChoreResponsibility> { old } };
        var uow = new Mock<IUnitOfWork>();
        uow.Setup(x => x.ChoreOccurrences.AddResponsibilityAsync(It.IsAny<ChoreResponsibility>(),It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        var replacement = Guid.NewGuid();
        await ChoreResponsibilityService.AssignAsync(uow.Object,occurrence,replacement,"CHORE_PASS",now.AddHours(24),now,default);
        Assert.Equal(3,old.PenaltiesApplied); Assert.Equal(now,old.EndedAt);
        var current = Assert.Single(occurrence.Responsibilities,x => x.EndedAt == null);
        Assert.Equal(replacement,current.UserId); Assert.Equal(0,current.PenaltiesApplied);
        Assert.Equal(now.AddHours(24),current.Deadline);
        Assert.False(occurrence.IsForcedReassigned);
    }
}
