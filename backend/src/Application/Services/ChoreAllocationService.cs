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

public class ChoreAllocationService : IChoreAllocationService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ChoreAllocationService> _logger;

    public ChoreAllocationService(IUnitOfWork unitOfWork, ILogger<ChoreAllocationService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task AllocateSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation($"Starting allocation for season {seasonId}");

        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        if (season.AllocationMethod != AllocationMethod.AUTOMATIC)
            throw new ConflictException("Season allocation method is not set to AUTOMATIC.");

        var unassignedOccurrences = (await _unitOfWork.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, cancellationToken)).ToList();
        if (!unassignedOccurrences.Any())
        {
            _logger.LogWarning($"No unassigned occurrences found for season {seasonId}");
            return; // Nothing to allocate
        }

        var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE)
            .ToList();

        if (!members.Any())
            throw new ConflictException("No active members in the household to assign chores to.");

        var availabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(seasonId, cancellationToken); // Wait, we don't have GetBySeasonIdAsync yet, let's just get it per member or use a new method. I'll need to create GetBySeasonIdAsync.

        // Initialize assigned karma tracker for this allocation session to balance workload
        var assignedKarma = members.ToDictionary(m => m.UserId, m => 0);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            foreach (var occurrence in unassignedOccurrences)
            {
                var dayOfWeek = occurrence.DueDate.DayOfWeek;

                // Find eligible members (available on this day)
                // If a user has explicitly set IsAvailable = false for this DayOfWeek, they are not eligible.
                // Otherwise, they are eligible.
                var eligibleMembers = members.Where(m => 
                {
                    var availability = availabilities.FirstOrDefault(a => a.UserId == m.UserId && a.DayOfWeek == dayOfWeek);
                    return availability == null || availability.IsAvailable;
                }).ToList();

                // If no one is available, fallback to all members
                if (!eligibleMembers.Any())
                    eligibleMembers = members;

                // Sort by least assigned karma in this session, then by least overall KarmaBalance to distribute fairly
                var assignee = eligibleMembers
                    .OrderBy(m => assignedKarma[m.UserId])
                    .ThenBy(m => m.KarmaBalance)
                    .First();

                occurrence.AssignedUserId = assignee.UserId;
                assignedKarma[assignee.UserId] += occurrence.SnapshotKarma;

                _unitOfWork.ChoreOccurrences.Update(occurrence);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
            
            _logger.LogInformation($"Successfully allocated {unassignedOccurrences.Count} occurrences for season {seasonId}");
        }
        catch (Exception ex)
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            _logger.LogError(ex, $"Failed to allocate occurrences for season {seasonId}");
            throw;
        }
    }

    public async Task AllocateAllActiveSeasonsAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting AllocateAllActiveSeasonsAsync");
        var activeSeasons = await _unitOfWork.Seasons.GetActiveSeasonsAsync(DateTime.UtcNow, cancellationToken);
        var autoSeasons = activeSeasons.Where(s => s.AllocationMethod == AllocationMethod.AUTOMATIC).ToList();

        foreach (var season in autoSeasons)
        {
            try
            {
                await AllocateSeasonAsync(season.Id, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to allocate season {season.Id} in background worker.");
            }
        }
    }
}
