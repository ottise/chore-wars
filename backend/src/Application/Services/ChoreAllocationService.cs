using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
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

    public async Task AllocateChoresAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting AllocateChoresAsync.");

        var now = DateTime.UtcNow;
        var activeSeasons = await _unitOfWork.Seasons.GetActiveSeasonsAsync(now, cancellationToken);
        var autoSeasons = activeSeasons.Where(s => s.AllocationMethod == AllocationMethod.AUTOMATIC).ToList();

        foreach (var season in autoSeasons)
        {
            try
            {
                await _unitOfWork.BeginTransactionAsync(cancellationToken);

                // For simplicity in this implementation, we will fetch chores in the season
                var chores = await _unitOfWork.Chores.GetBySeasonIdAsync(season.Id, cancellationToken);
                var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken);
                
                // Logic to allocate chores:
                // 1. Identify which chores need occurrences generated based on FrequencyType (daily, weekly, specific days).
                // 2. Identify available members.
                // 3. Assign occurrences balancing availability, workload, karma.
                
                foreach (var chore in chores)
                {
                    // Basic placeholder for assignment logic
                    // We'll assign to the member with highest karma for now
                    if (members.Any())
                    {
                        var assignee = members.OrderByDescending(m => m.KarmaBalance).First();
                        
                        // Just a dummy logic to avoid too much generation: only if no occurrences exist for today
                        // In reality, this requires tracking last generated date per chore.
                        var occurrences = await _unitOfWork.ChoreOccurrences.GetByChoreIdAsync(chore.Id, cancellationToken);
                        if (!occurrences.Any(o => o.DueDate.Date == now.Date))
                        {
                            var occurrence = new ChoreOccurrence
                            {
                                Id = Guid.NewGuid(),
                                ChoreId = chore.Id,
                                AssignedUserId = assignee.UserId,
                                DueDate = now.AddDays(1), // due tomorrow
                                Status = ChoreOccurrenceStatus.ASSIGNED,
                                PenaltyCount = 0
                            };
                            
                            await _unitOfWork.ChoreOccurrences.AddAsync(occurrence, cancellationToken);
                        }
                    }
                }

                await _unitOfWork.SaveChangesAsync(cancellationToken);
                await _unitOfWork.CommitTransactionAsync(cancellationToken);
                
                _logger.LogInformation($"Processed allocation for season {season.Id}.");
            }
            catch (Exception ex)
            {
                await _unitOfWork.RollbackTransactionAsync(cancellationToken);
                _logger.LogError(ex, $"Error allocating chores for season {season.Id}.");
            }
        }

        _logger.LogInformation("Completed AllocateChoresAsync.");
    }
}
