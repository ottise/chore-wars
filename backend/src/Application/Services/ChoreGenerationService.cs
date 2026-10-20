using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Application.Services;

public class ChoreGenerationService : IChoreGenerationService
{
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ChoreGenerationService> _logger;

    public ChoreGenerationService(IUnitOfWork unitOfWork, ILogger<ChoreGenerationService> logger, TimeProvider? clock = null)
    {
        _clock = clock ?? TimeProvider.System;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task GenerateOccurrencesAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation($"Starting chore generation for season {seasonId}");

        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException("Season not found.");

        if (season.Status != SeasonStatus.DRAFT)
            throw new ConflictException("Can only generate chores for seasons in DRAFT status.");

        // House member permission check
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("You are not a member of this household.");

        // Check for duplicates
        var hasOccurrences = await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(seasonId, cancellationToken);
        if (hasOccurrences)
            throw new ConflictException("Occurrences have already been generated for this season.");

        var chores = await _unitOfWork.Chores.GetBySeasonIdAsync(season.Id, cancellationToken);
        if (!chores.Any())
            throw new ConflictException("No chore templates found for this season.");

        var occurrencesToCreate = new List<ChoreOccurrence>();

        foreach (var chore in chores)
        {
            var occurrences = GenerateForChore(chore, season.Id, season.StartDate, season.EndDate);
            occurrencesToCreate.AddRange(occurrences);
        }

        if (!occurrencesToCreate.Any())
        {
            _logger.LogWarning($"No occurrences generated for season {seasonId}");
            return;
        }

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.ChoreOccurrences.AddRangeAsync(occurrencesToCreate, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
            
            _logger.LogInformation($"Successfully generated {occurrencesToCreate.Count} occurrences for season {seasonId}");
        }
        catch (Exception ex)
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            _logger.LogError(ex, $"Failed to generate occurrences for season {seasonId}");
            throw;
        }
    }

    private IEnumerable<ChoreOccurrence> GenerateForChore(Chore chore, Guid seasonId, DateTime startDate, DateTime endDate)
    {
        return RecurrenceCalculator.Dates(chore, DateOnly.FromDateTime(ScheduleTime.Local(startDate)), DateOnly.FromDateTime(ScheduleTime.Local(endDate)))
            .Select(day => new ChoreOccurrence {
                Id = Guid.NewGuid(), ChoreId = chore.Id, SeasonId = seasonId,
                DueDate = ScheduleTime.Utc(day, chore.DeadlineMinutes),
                Status = ChoreOccurrenceStatus.ASSIGNED, SnapshotKarma = chore.KarmaPoints,
                SnapshotMinutes = ScheduleTime.Effort(chore.Difficulty),
                SnapshotDifficulty = chore.Difficulty
            });
    }
}
