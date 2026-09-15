using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace ChoreWars.UnitTests.Services;

public class ChoreGenerationServiceTests
{
    private readonly Mock<IUnitOfWork> _mockUnitOfWork;
    private readonly Mock<ILogger<ChoreGenerationService>> _mockLogger;
    private readonly ChoreGenerationService _service;

    public ChoreGenerationServiceTests()
    {
        _mockUnitOfWork = new Mock<IUnitOfWork>();
        _mockLogger = new Mock<ILogger<ChoreGenerationService>>();
        
        _mockUnitOfWork.Setup(u => u.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        _service = new ChoreGenerationService(_mockUnitOfWork.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task GenerateOccurrences_SeasonNotFound_ThrowsNotFoundException()
    {
        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((ChoreSeason?)null);

        await Assert.ThrowsAsync<NotFoundException>(() => _service.GenerateOccurrencesAsync(Guid.NewGuid(), Guid.NewGuid()));
    }

    [Fact]
    public async Task GenerateOccurrences_SeasonNotDraft_ThrowsConflictException()
    {
        var season = new ChoreSeason { Status = SeasonStatus.ACTIVE };
        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(season);

        await Assert.ThrowsAsync<ConflictException>(() => _service.GenerateOccurrencesAsync(Guid.NewGuid(), Guid.NewGuid()));
    }

    [Fact]
    public async Task GenerateOccurrences_UserNotMember_ThrowsForbiddenException()
    {
        var season = new ChoreSeason { HouseId = Guid.NewGuid(), Status = SeasonStatus.DRAFT };
        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(season);
            
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseAndUserIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((HouseMember?)null);

        await Assert.ThrowsAsync<ForbiddenException>(() => _service.GenerateOccurrencesAsync(Guid.NewGuid(), Guid.NewGuid()));
    }
    
    [Fact]
    public async Task GenerateOccurrences_AlreadyGenerated_ThrowsConflictException()
    {
        var season = new ChoreSeason { HouseId = Guid.NewGuid(), Status = SeasonStatus.DRAFT };
        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(season);
            
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseAndUserIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember());

        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.HasOccurrencesForSeasonAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<ConflictException>(() => _service.GenerateOccurrencesAsync(Guid.NewGuid(), Guid.NewGuid()));
    }
    
    [Fact]
    public async Task GenerateOccurrences_ValidSeason_GeneratesCorrectNumberOfOccurrences()
    {
        var seasonId = Guid.NewGuid();
        var startDate = new DateTime(2023, 10, 1); // Sunday
        var endDate = new DateTime(2023, 10, 14); // 2 weeks (14 days)
        var season = new ChoreSeason { 
            Id = seasonId,
            HouseId = Guid.NewGuid(), 
            Status = SeasonStatus.DRAFT,
            StartDate = startDate,
            EndDate = endDate
        };
        
        var dailyChore = new Chore { 
            Id = Guid.NewGuid(), 
            SeasonId = seasonId, 
            FrequencyType = FrequencyType.DAILY,
            KarmaPoints = 10
        };
        
        var weeklyChore = new Chore {
            Id = Guid.NewGuid(),
            SeasonId = seasonId,
            FrequencyType = FrequencyType.WEEKLY, // By default occurs on same day of week as StartDate (Sunday)
            KarmaPoints = 20
        };
        
        var specificDaysChore = new Chore {
            Id = Guid.NewGuid(),
            SeasonId = seasonId,
            FrequencyType = FrequencyType.SPECIFIC_DAYS,
            KarmaPoints = 30,
            FrequencyDays = new List<ChoreFrequencyDay> 
            { 
                new ChoreFrequencyDay { DayOfWeek = DayOfWeek.Monday },
                new ChoreFrequencyDay { DayOfWeek = DayOfWeek.Wednesday }
            }
        };

        var chores = new List<Chore> { dailyChore, weeklyChore, specificDaysChore };

        _mockUnitOfWork.Setup(u => u.Seasons.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(season);
            
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseAndUserIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new HouseMember());

        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.HasOccurrencesForSeasonAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
            
        _mockUnitOfWork.Setup(u => u.Chores.GetBySeasonIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(chores);

        IEnumerable<ChoreOccurrence>? savedOccurrences = null;
        _mockUnitOfWork.Setup(u => u.ChoreOccurrences.AddRangeAsync(It.IsAny<IEnumerable<ChoreOccurrence>>(), It.IsAny<CancellationToken>()))
            .Callback<IEnumerable<ChoreOccurrence>, CancellationToken>((occ, ct) => savedOccurrences = occ)
            .Returns(Task.CompletedTask);

        await _service.GenerateOccurrencesAsync(seasonId, Guid.NewGuid());

        Assert.NotNull(savedOccurrences);
        var occurrencesList = savedOccurrences.ToList();
        
        // 14 days total
        // Daily chore: 14 occurrences
        Assert.Equal(14, occurrencesList.Count(o => o.ChoreId == dailyChore.Id));
        
        // Weekly chore on Sunday (Oct 1 and Oct 8): 2 occurrences
        Assert.Equal(2, occurrencesList.Count(o => o.ChoreId == weeklyChore.Id));
        
        // Specific Days (Mon, Wed) across 2 weeks: 4 occurrences
        Assert.Equal(4, occurrencesList.Count(o => o.ChoreId == specificDaysChore.Id));
        
        // Total = 20 occurrences
        Assert.Equal(20, occurrencesList.Count);
        
        // Check Karma Snapshot
        Assert.All(occurrencesList.Where(o => o.ChoreId == dailyChore.Id), o => Assert.Equal(10, o.SnapshotKarma));
        Assert.All(occurrencesList.Where(o => o.ChoreId == weeklyChore.Id), o => Assert.Equal(20, o.SnapshotKarma));
        Assert.All(occurrencesList.Where(o => o.ChoreId == specificDaysChore.Id), o => Assert.Equal(30, o.SnapshotKarma));
    }
}
