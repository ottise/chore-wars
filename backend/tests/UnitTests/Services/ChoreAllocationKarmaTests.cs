using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using System.Globalization;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace UnitTests.Services;

public class ChoreAllocationKarmaTests
{
    private readonly Mock<IUnitOfWork> _mockUnitOfWork;
    private readonly Mock<ILogger<ChoreAllocationService>> _mockLogger;
    private readonly ChoreAllocationService _service;

    public ChoreAllocationKarmaTests()
    {
        _mockUnitOfWork = new Mock<IUnitOfWork>();
        _mockLogger = new Mock<ILogger<ChoreAllocationService>>();

        _mockUnitOfWork.Setup(u => u.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        _service = new ChoreAllocationService(_mockUnitOfWork.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task AllocateSeasonAsync_ShouldBalanceKarma_AcrossAllMembers()
    {
        // Arrange
        var houseId = Guid.NewGuid();
        var seasonId = Guid.NewGuid();
        var season = new ChoreSeason
        {
            Id = seasonId,
            HouseId = houseId,
            Status = SeasonStatus.DRAFT, AllocationMethod = AllocationMethod.AUTOMATIC,
            StartDate = new DateTime(2026, 10, 5),
            EndDate = new DateTime(2026, 11, 1)
        };

        var memberA = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Alice" } };
        var memberB = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Bob" } };
        var memberC = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Charlie" } };
        var members = new List<HouseMember> { memberA, memberB, memberC };

        var choreA = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Deep Clean Kitchen", KarmaPoints = 50, Difficulty = ChoreEffort.HARD, EstimatedMinutes = 60 };
        var choreB = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Mop Living Room", KarmaPoints = 40, Difficulty = ChoreEffort.MEDIUM, EstimatedMinutes = 40 };
        var choreC = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Wash Bathrooms", KarmaPoints = 30, Difficulty = ChoreEffort.MEDIUM, EstimatedMinutes = 35 };
        var choreD = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Take out Trash", KarmaPoints = 25, Difficulty = ChoreEffort.EASY, EstimatedMinutes = 20 };
        var choreE = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Water Plants", KarmaPoints = 25, Difficulty = ChoreEffort.EASY, EstimatedMinutes = 20 };
        var choreF = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Wipe Windows", KarmaPoints = 20, Difficulty = ChoreEffort.EASY, EstimatedMinutes = 15 };

        var occurrences = new List<ChoreOccurrence>
        {
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = choreA.Id, Chore = choreA, DueDate = new DateTime(2026, 10, 6) },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = choreB.Id, Chore = choreB, DueDate = new DateTime(2026, 10, 7) },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = choreC.Id, Chore = choreC, DueDate = new DateTime(2026, 10, 8) },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = choreD.Id, Chore = choreD, DueDate = new DateTime(2026, 10, 9) },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = choreE.Id, Chore = choreE, DueDate = new DateTime(2026, 10, 10) },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = choreF.Id, Chore = choreF, DueDate = new DateTime(2026, 10, 11) }
        };

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>())).ReturnsAsync(members);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);
        _mockUnitOfWork.Setup(u => u.MemberAvailabilities.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(members.SelectMany(m => Enumerable.Range(0, 7).Select(d => new MemberAvailability { UserId = m.UserId, SeasonId = seasonId, DayOfWeek = (DayOfWeek)d, IsAvailable = true })).ToList());
        _mockUnitOfWork.Setup(u => u.MemberConstraints.GetByUserAndHouseIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((MemberConstraint?)null);
        _mockUnitOfWork.Setup(u => u.MemberPreferences.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(new List<MemberPreference>());

        foreach (var occurrence in occurrences) occurrence.SnapshotKarma = occurrence.Chore.KarmaPoints;
        // Act
        await _service.AllocateSeasonAsync(seasonId);

        // Assert
        Assert.All(occurrences, o => Assert.NotNull(o.AssignedUserId));

        var karmaA = occurrences.Where(o => o.AssignedUserId == memberA.UserId).Sum(o => o.Chore.KarmaPoints);
        var karmaB = occurrences.Where(o => o.AssignedUserId == memberB.UserId).Sum(o => o.Chore.KarmaPoints);
        var karmaC = occurrences.Where(o => o.AssignedUserId == memberC.UserId).Sum(o => o.Chore.KarmaPoints);

        var memberKarmas = new[] { (double)karmaA, (double)karmaB, (double)karmaC };
        var avgKarma = memberKarmas.Average();
        var variance = memberKarmas.Sum(k => Math.Pow(k - avgKarma, 2)) / memberKarmas.Length;
        var stdDev = Math.Sqrt(variance);
        var stdDevPercentage = (stdDev / avgKarma) * 100.0;

        // Relative standard deviation (Độ lệch chuẩn) must be <= 20%
        Assert.True(stdDevPercentage <= 20.0, $"Standard deviation was {stdDevPercentage:F1}%, which exceeds 20%. Karma distribution: A={karmaA}, B={karmaB}, C={karmaC}");
    }

    [Fact]
    public async Task AllocateSeasonAsync_ShouldAvoidAssigningSameChore_InConsecutiveWeeks()
    {
        // Arrange
        var houseId = Guid.NewGuid();
        var seasonId = Guid.NewGuid();
        var season = new ChoreSeason
        {
            Id = seasonId,
            HouseId = houseId,
            Status = SeasonStatus.DRAFT, AllocationMethod = AllocationMethod.AUTOMATIC,
            StartDate = new DateTime(2026, 10, 5),
            EndDate = new DateTime(2026, 11, 2)
        };

        var memberA = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Alice" } };
        var memberB = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Bob" } };
        var members = new List<HouseMember> { memberA, memberB };

        var chore = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Kitchen Scrub", KarmaPoints = 30, Difficulty = ChoreEffort.MEDIUM, EstimatedMinutes = 30 };

        // 4 occurrences across 4 consecutive Mondays (Weeks 41, 42, 43, 44)
        var occurrences = new List<ChoreOccurrence>
        {
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = chore.Id, Chore = chore, DueDate = new DateTime(2026, 10, 5) },  // Week 41
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = chore.Id, Chore = chore, DueDate = new DateTime(2026, 10, 12) }, // Week 42
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = chore.Id, Chore = chore, DueDate = new DateTime(2026, 10, 19) }, // Week 43
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = chore.Id, Chore = chore, DueDate = new DateTime(2026, 10, 26) }  // Week 44
        };

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>())).ReturnsAsync(members);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);
        _mockUnitOfWork.Setup(u => u.MemberAvailabilities.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(members.SelectMany(m => Enumerable.Range(0, 7).Select(d => new MemberAvailability { UserId = m.UserId, SeasonId = seasonId, DayOfWeek = (DayOfWeek)d, IsAvailable = true })).ToList());
        _mockUnitOfWork.Setup(u => u.MemberConstraints.GetByUserAndHouseIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((MemberConstraint?)null);
        _mockUnitOfWork.Setup(u => u.MemberPreferences.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(new List<MemberPreference>());

        foreach (var occurrence in occurrences) occurrence.SnapshotKarma = occurrence.Chore.KarmaPoints;
        // Act
        await _service.AllocateSeasonAsync(seasonId);

        // Assert
        var sorted = occurrences.OrderBy(o => o.DueDate).ToList();
        Assert.NotNull(sorted[0].AssignedUserId);
        Assert.NotNull(sorted[1].AssignedUserId);
        Assert.NotNull(sorted[2].AssignedUserId);
        Assert.NotNull(sorted[3].AssignedUserId);

        // Check that consecutive weeks rotate between members
        Assert.NotEqual(sorted[0].AssignedUserId, sorted[1].AssignedUserId);
        Assert.NotEqual(sorted[1].AssignedUserId, sorted[2].AssignedUserId);
        Assert.NotEqual(sorted[2].AssignedUserId, sorted[3].AssignedUserId);
    }

    [Fact]
    public async Task AllocateSeasonAsync_ShouldPopulateWarnings_WhenConstraintConflictsOccur()
    {
        // Arrange
        var houseId = Guid.NewGuid();
        var seasonId = Guid.NewGuid();
        var season = new ChoreSeason
        {
            Id = seasonId,
            HouseId = houseId,
            Status = SeasonStatus.DRAFT, AllocationMethod = AllocationMethod.AUTOMATIC,
            StartDate = new DateTime(2026, 10, 5),
            EndDate = new DateTime(2026, 10, 12)
        };

        var member = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Alice" } };
        var members = new List<HouseMember> { member };

        // Alice is marked UNAVAILABLE on Monday
        var availabilities = new List<MemberAvailability>
        {
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, UserId = member.UserId, DayOfWeek = DayOfWeek.Monday, IsAvailable = false }
        };

        var chore = new Chore { Id = Guid.NewGuid(), HouseId = houseId, Name = "Monday Laundry", KarmaPoints = 20, Difficulty = ChoreEffort.EASY, EstimatedMinutes = 30 };
        var occurrences = new List<ChoreOccurrence>
        {
            // Due on Monday, Oct 5
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, ChoreId = chore.Id, Chore = chore, DueDate = new DateTime(2026, 10, 5) }
        };

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>())).ReturnsAsync(members);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);
        _mockUnitOfWork.Setup(u => u.MemberAvailabilities.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(availabilities);
        _mockUnitOfWork.Setup(u => u.MemberConstraints.GetByUserAndHouseIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((MemberConstraint?)null);
        _mockUnitOfWork.Setup(u => u.MemberPreferences.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(new List<MemberPreference>());

        foreach (var occurrence in occurrences) occurrence.SnapshotKarma = occurrence.Chore.KarmaPoints;
        // Act
        await _service.AllocateSeasonAsync(seasonId);
        var workloadSummary = await _service.GetWorkloadSummaryAsync(seasonId);

        // Assert
        Assert.NotEmpty(workloadSummary.Warnings);
        Assert.Equal(1, workloadSummary.UnassignedCount);
        Assert.Null(occurrences.Single().AssignedUserId);
    }

    [Fact]
    public async Task GetWorkloadSummaryAsync_ShouldReturnAccurateTotalKarma()
    {
        // Arrange
        var houseId = Guid.NewGuid();
        var seasonId = Guid.NewGuid();
        var season = new ChoreSeason { Id = seasonId, HouseId = houseId, Status = SeasonStatus.REVIEWING };

        var userA = Guid.NewGuid();
        var userB = Guid.NewGuid();
        var memberA = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = userA, Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Alice" } };
        var memberB = new HouseMember { Id = Guid.NewGuid(), HouseId = houseId, UserId = userB, Status = HouseMemberStatus.ACTIVE, User = new User { DisplayName = "Bob" } };
        var members = new List<HouseMember> { memberA, memberB };

        var chore1 = new Chore { Id = Guid.NewGuid(), Name = "Vacuum", KarmaPoints = 35, Difficulty = ChoreEffort.MEDIUM, EstimatedMinutes = 30 };
        var chore2 = new Chore { Id = Guid.NewGuid(), Name = "Dishes", KarmaPoints = 15, Difficulty = ChoreEffort.EASY, EstimatedMinutes = 15 };
        var chore3 = new Chore { Id = Guid.NewGuid(), Name = "Cook Dinner", KarmaPoints = 40, Difficulty = ChoreEffort.HARD, EstimatedMinutes = 45 };

        var occurrences = new List<ChoreOccurrence>
        {
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, Chore = chore1, AssignedUserId = userA, DueDate = DateTime.UtcNow },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, Chore = chore2, AssignedUserId = userA, DueDate = DateTime.UtcNow },
            new() { Id = Guid.NewGuid(), SeasonId = seasonId, Chore = chore3, AssignedUserId = userB, DueDate = DateTime.UtcNow }
        };

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>())).ReturnsAsync(members);
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(occurrences);

        foreach (var occurrence in occurrences) occurrence.SnapshotKarma = occurrence.Chore.KarmaPoints;
        // Act
        _mockUnitOfWork.Setup(u => u.MemberAvailabilities.GetBySeasonIdAsync(seasonId, It.IsAny<CancellationToken>())).ReturnsAsync(new List<MemberAvailability>());
        var summary = await _service.GetWorkloadSummaryAsync(seasonId);

        // Assert
        Assert.NotNull(summary);
        Assert.Equal(2, summary.Members.Count);

        var workloadA = summary.Members.Single(m => m.UserId == userA);
        var workloadB = summary.Members.Single(m => m.UserId == userB);

        Assert.Equal(50, workloadA.TotalKarma); // 35 + 15
        Assert.Equal(40, workloadB.TotalKarma); // 40
        Assert.Equal(2, workloadA.TotalChores);
        Assert.Equal(1, workloadB.TotalChores);

        // Avg = 45, Gap = 10, Variance = (10 / 45) * 100 = 22.22%
        Assert.Equal(22.22, summary.KarmaVariancePercentage);
    }
}
