using AutoMapper;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Mappings;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public class ChoreCreationWorkflowTests {
    private sealed class FixedClock : TimeProvider {
        public override DateTimeOffset GetUtcNow() => new(2026, 10, 30, 6, 0, 0, TimeSpan.Zero);
    }
    private sealed class Fixture {
        public Guid User = Guid.NewGuid();
        public House House = new() { Id = Guid.NewGuid() };
        public ChoreSeason Season;
        public HouseMember Member;
        public List<Chore> Chores = [];
        public List<ChoreOccurrence> Occurrences = [];
        public List<SeasonConfirmation> Confirmations = [];
        public Mock<IUnitOfWork> Uow = new();
        public ChoreService Service;
        public Fixture(SeasonStatus status = SeasonStatus.ACTIVE, bool available = true) {
            Season = new() { Id = Guid.NewGuid(), HouseId = House.Id, Name = "October", Status = status, AllocationMethod = AllocationMethod.AUTOMATIC,
                StartDate = ScheduleTime.Utc(new(2026, 10, 29), 0), EndDate = ScheduleTime.Utc(new(2026, 11, 1), 1439), ScheduleRevision = 4 };
            Member = new() { HouseId = House.Id, UserId = User, Status = HouseMemberStatus.ACTIVE, Role = HouseRole.MEMBER };
            Uow.Setup(x => x.Houses.GetByIdAsync(House.Id, It.IsAny<CancellationToken>())).ReturnsAsync(House);
            Uow.Setup(x => x.HouseMembers.GetByHouseAndUserIdAsync(House.Id, User, It.IsAny<CancellationToken>())).ReturnsAsync(Member);
            Uow.Setup(x => x.HouseMembers.GetByHouseIdAsync(House.Id, It.IsAny<CancellationToken>())).ReturnsAsync(new[] { Member });
            Uow.Setup(x => x.Seasons.GetCurrentSeasonByHouseIdAsync(House.Id, It.IsAny<CancellationToken>())).ReturnsAsync(Season);
            Uow.Setup(x => x.Seasons.GetByIdAsync(Season.Id, It.IsAny<CancellationToken>())).ReturnsAsync(Season);
            Uow.Setup(x => x.Chores.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Guid id, CancellationToken _) => Chores.FirstOrDefault(c => c.Id == id));
            Uow.Setup(x => x.Chores.GetBySeasonIdAsync(Season.Id, It.IsAny<CancellationToken>())).ReturnsAsync(() => Chores.Where(c => c.SeasonId == Season.Id));
            Uow.Setup(x => x.Chores.AddAsync(It.IsAny<Chore>(), It.IsAny<CancellationToken>())).Callback<Chore, CancellationToken>((c, _) => Chores.Add(c)).Returns(Task.CompletedTask);
            Uow.Setup(x => x.ChoreOccurrences.GetBySeasonIdAsync(Season.Id, It.IsAny<CancellationToken>())).ReturnsAsync(() => Occurrences);
            Uow.Setup(x => x.ChoreOccurrences.GetByChoreIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Guid id, CancellationToken _) => Occurrences.Where(o => o.ChoreId == id));
            Uow.Setup(x => x.ChoreOccurrences.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Guid id, CancellationToken _) => Occurrences.FirstOrDefault(o => o.Id == id));
            Uow.Setup(x => x.ChoreOccurrences.AddRangeAsync(It.IsAny<IEnumerable<ChoreOccurrence>>(), It.IsAny<CancellationToken>())).Callback<IEnumerable<ChoreOccurrence>, CancellationToken>((o, _) => Occurrences.AddRange(o)).Returns(Task.CompletedTask);
            Uow.Setup(x => x.MemberAvailabilities.GetBySeasonIdAsync(Season.Id, It.IsAny<CancellationToken>())).ReturnsAsync(Enum.GetValues<DayOfWeek>().Select(d => new MemberAvailability { UserId = User, DayOfWeek = d, IsAvailable = available }));
            Uow.Setup(x => x.MemberAvailabilities.GetExceptionsBySeasonAsync(Season.Id, It.IsAny<CancellationToken>())).ReturnsAsync(Array.Empty<MemberAvailabilityException>());
            Uow.Setup(x => x.MemberConstraints.GetByUserAndHouseIdAsync(User, House.Id, It.IsAny<CancellationToken>())).ReturnsAsync(new MemberConstraint { MaxChoresPerWeek = 20, MaxEffortMinutesPerDay = 180 });
            Uow.Setup(x => x.SeasonConfirmations.DeleteBySeasonIdAsync(Season.Id, It.IsAny<CancellationToken>())).Callback(() => Confirmations.Clear()).Returns(Task.CompletedTask);
            Uow.Setup(x => x.SeasonConfirmations.GetBySeasonIdAsync(Season.Id, It.IsAny<CancellationToken>())).ReturnsAsync(() => Confirmations);
            Uow.Setup(x => x.SeasonConfirmations.AddAsync(It.IsAny<SeasonConfirmation>(), It.IsAny<CancellationToken>())).Callback<SeasonConfirmation, CancellationToken>((c, _) => Confirmations.Add(c)).Returns(Task.CompletedTask);
            Uow.Setup(x => x.ChoreFrequencyDays.AddAsync(It.IsAny<ChoreFrequencyDay>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            var mapper = new MapperConfiguration(c => c.AddProfile<ChoreProfile>()).CreateMapper();
            Service = new(Uow.Object, mapper, Mock.Of<IEventPublisher>(), Mock.Of<IKarmaService>(), clock: new FixedClock());
        }
        public CreateChoreRequest Request() => new() { Name = "Clean kitchen", KarmaPoints = 10, FrequencyType = FrequencyType.DAILY, ClientRequestId = Guid.NewGuid() };
        public Task<ChoreResponse> Create(CreateChoreRequest r) => Service.CreateChoreAsync(House.Id, r, User);
    }

    [Theory]
    [InlineData(SeasonStatus.DRAFT)] [InlineData(SeasonStatus.REVIEWING)] [InlineData(SeasonStatus.ACTIVE)]
    public async Task ActiveMemberCreatesRealOccurrencesWithoutDeletingExistingSchedule(SeasonStatus status) {
        var f = new Fixture(status);
        var historical = new ChoreOccurrence { Id = Guid.NewGuid(), Status = ChoreOccurrenceStatus.COMPLETED, EvidenceId = Guid.NewGuid(), SnapshotKarma = 77 };
        f.Occurrences.Add(historical);
        var result = await f.Create(f.Request());
        Assert.Equal(5, result.ScheduleRevision);
        Assert.NotEmpty(result.OccurrenceIds);
        Assert.Contains(historical, f.Occurrences);
        Assert.Equal(77, historical.SnapshotKarma);
        Assert.Equal(ChoreOccurrenceStatus.COMPLETED, historical.Status);
        Assert.Equal("assigned", result.AssignmentStatus);
        f.Uow.Verify(x => x.ChoreOccurrences.DeleteBySeasonIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
        if (status == SeasonStatus.ACTIVE) Assert.All(f.Occurrences.Where(o => o != historical), o => { Assert.True(o.DueDate > new FixedClock().GetUtcNow().UtcDateTime); Assert.True(o.PlannedStartAt >= new FixedClock().GetUtcNow().UtcDateTime); });
        if (status == SeasonStatus.REVIEWING) Assert.All(f.Confirmations, c => { Assert.Equal(5, c.ScheduleRevision); Assert.Equal(ConfirmationStatus.PENDING, c.Status); });
    }

    [Fact] public async Task RetryReturnsSameChoreAndOccurrencesWithoutAdvancingRevision() {
        var f = new Fixture(); var request = f.Request();
        var first = await f.Create(request); var second = await f.Create(request);
        Assert.Equal(first.Id, second.Id); Assert.Equal(first.OccurrenceIds, second.OccurrenceIds); Assert.Single(f.Chores); Assert.Equal(5, f.Season.ScheduleRevision);
        request.Name = "Different payload";
        await Assert.ThrowsAsync<ConflictException>(() => f.Create(request));
    }

    [Fact] public async Task NoAvailabilityReturnsNeedsAssignmentWithoutInventingAnAssignee() {
        var f = new Fixture(available: false); var result = await f.Create(f.Request());
        Assert.Equal("needs_assignment", result.AssignmentStatus); Assert.NotEmpty(result.AssignmentReason!);
        Assert.All(f.Occurrences, o => Assert.Null(o.AssignedUserId));
    }

    [Theory] [InlineData(HouseMemberStatus.LEFT)] [InlineData(HouseMemberStatus.BANNED)]
    public async Task InactiveMemberCannotCreate(HouseMemberStatus status) {
        var f = new Fixture(); f.Member.Status = status;
        await Assert.ThrowsAsync<ForbiddenException>(() => f.Create(f.Request())); Assert.Empty(f.Chores);
    }

    [Fact] public async Task ArchivedHouseAndStaleRevisionRejectBeforeWriting() {
        var f = new Fixture(); f.House.IsArchived = true;
        await Assert.ThrowsAsync<ConflictException>(() => f.Create(f.Request()));
        f.House.IsArchived = false; var request = f.Request(); request.ExpectedRevision = 3;
        await Assert.ThrowsAsync<ConflictException>(() => f.Create(request)); Assert.Empty(f.Chores);
    }

    [Theory] [InlineData(SeasonStatus.COMPLETED)] [InlineData(SeasonStatus.CANCELLED)]
    public async Task ClosedSeasonNeverSilentlySavesRoutine(SeasonStatus status) {
        var f = new Fixture(status); var request = f.Request(); request.AsRoutine = true;
        await Assert.ThrowsAsync<ConflictException>(() => f.Create(request)); Assert.Empty(f.Chores);
    }

    [Fact] public async Task DetailReturnsActualHouseSeasonAndOverdueCapabilities() {
        var f = new Fixture(); await f.Create(f.Request()); var task = f.Occurrences[0]; task.Status = ChoreOccurrenceStatus.OVERDUE;
        var response = await f.Service.GetOccurrenceAsync(task.Id, f.User);
        Assert.Equal(f.House.Id, response.HouseId); Assert.Equal(f.Season.Id, response.SeasonId); Assert.Equal("October", response.SeasonName);
        Assert.True(response.CanComplete); Assert.True(response.CanUploadEvidence);
        task.Status = ChoreOccurrenceStatus.COMPLETED;
        response = await f.Service.GetOccurrenceAsync(task.Id, f.User);
        Assert.False(response.CanComplete);
    }
}
