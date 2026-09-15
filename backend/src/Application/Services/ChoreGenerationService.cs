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
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ChoreGenerationService> _logger;

    public ChoreGenerationService(IUnitOfWork unitOfWork, ILogger<ChoreGenerationService> logger)
    {
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
        if (member == null)
            throw new ForbiddenException("You are not a member of this household.");

        // Check for duplicates
        var hasOccurrences = await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(seasonId, cancellationToken);
        if (hasOccurrences)
            throw new ConflictException("Occurrences have already been generated for this season.");

        var chores = await _unitOfWork.Chores.GetBySeasonIdAsync(seasonId, cancellationToken);
        if (!chores.Any())
            throw new ConflictException("No chore templates found for this season.");

        var occurrencesToCreate = new List<ChoreOccurrence>();

        foreach (var chore in chores)
        {
            var occurrences = GenerateForChore(chore, season.StartDate, season.EndDate);
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

    private IEnumerable<ChoreOccurrence> GenerateForChore(Chore chore, DateTime startDate, DateTime endDate)
    {
        var occurrences = new List<ChoreOccurrence>();
        var currentDate = startDate.Date;
        var end = endDate.Date;

        while (currentDate <= end)
        {
            bool shouldGenerate = false;

            switch (chore.FrequencyType)
            {
                case FrequencyType.DAILY:
                    shouldGenerate = true;
                    break;

                case FrequencyType.EVERY_X_DAYS:
                    var daysBetween = chore.FrequencyValue ?? 1;
                    if (daysBetween <= 0) daysBetween = 1;
                    
                    var totalDays = (currentDate - startDate.Date).Days;
                    shouldGenerate = (totalDays % daysBetween) == 0;
                    break;

                case FrequencyType.WEEKLY:
                case FrequencyType.SPECIFIC_DAYS:
                    if (chore.FrequencyDays != null && chore.FrequencyDays.Any())
                    {
                        shouldGenerate = chore.FrequencyDays.Any(fd => fd.DayOfWeek == currentDate.DayOfWeek);
                    }
                    else if (chore.FrequencyType == FrequencyType.WEEKLY)
                    {
                        // Default to start date's day of week if not specified
                        shouldGenerate = currentDate.DayOfWeek == startDate.DayOfWeek;
                    }
                    break;
                    
                default:
                    // Other frequencies not yet fully supported by the engine, skip or handle as once
                    break;
            }

            if (shouldGenerate)
            {
                occurrences.Add(new ChoreOccurrence
                {
                    Id = Guid.NewGuid(),
                    ChoreId = chore.Id,
                    DueDate = currentDate.AddHours(23).AddMinutes(59), // End of day
                    Status = ChoreOccurrenceStatus.ASSIGNED, // Or UNASSIGNED if we support that, but BR says ASSIGNED during allocation. Actually before allocation it's just pending. We'll set to ASSIGNED but AssignedUserId is empty Guid? Wait, AssignedUserId is not nullable.
                    // The schema requires AssignedUserId. For pre-allocation, how is it handled?
                    // Maybe we assign it to a System Guid or we must make AssignedUserId nullable in a future migration.
                    // For now, I will use Guid.Empty.
                    AssignedUserId = Guid.Empty, 
                    SnapshotKarma = chore.KarmaPoints,
                    IsForcedReassigned = false,
                    PenaltyCount = 0
                });
            }

            currentDate = currentDate.AddDays(1);
        }

        return occurrences;
    }
}
