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
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Events;

namespace ChoreWars.Application.Services;

public class OverduePenaltyService : IOverduePenaltyService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<OverduePenaltyService> _logger;
    private readonly IEventPublisher _eventPublisher;
    private readonly IKarmaService _karmaService;

    public OverduePenaltyService(
        IUnitOfWork unitOfWork,
        ILogger<OverduePenaltyService> logger,
        IEventPublisher eventPublisher,
        IKarmaService karmaService)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
        _eventPublisher = eventPublisher;
        _karmaService = karmaService;
    }

    public async Task ProcessOverduePenaltiesAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting ProcessOverduePenaltiesAsync.");

        var now = DateTime.UtcNow;

        // Note: Repository needs a method to get active non-completed occurrences that are past due
        // For simplicity, we can fetch all ASSIGNED or OVERDUE occurrences and process them
        // Better: A specific method GetOccurrencesEligibleForPenaltyAsync
        
        var occurrences = await _unitOfWork.ChoreOccurrences.GetOverdueEligibleOccurrencesAsync(now, cancellationToken);

        foreach (var occurrence in occurrences)
        {
            try
            {
                await _unitOfWork.BeginTransactionAsync(cancellationToken);

                // Calculate how many penalty intervals have passed since due date
                var timeOverdue = now - occurrence.DueDate;
                int expectedPenaltyCount = (int)(timeOverdue.TotalHours / PenaltyConstants.PenaltyIntervalHours);

                // Cap the penalty count
                if (expectedPenaltyCount > PenaltyConstants.MaxPenaltyCount)
                {
                    expectedPenaltyCount = PenaltyConstants.MaxPenaltyCount;
                }

                if (expectedPenaltyCount <= 0)
                {
                    await _unitOfWork.RollbackTransactionAsync(cancellationToken);
                    continue;
                }

                // Query KarmaTransactions for idempotency
                var existingPenalties = await _unitOfWork.KarmaTransactions.GetByReferenceIdAndTypeAsync(occurrence.Id, KarmaTransactionType.PENALTY, cancellationToken);
                int penaltiesApplied = existingPenalties.Count();

                int penaltiesToAdd = expectedPenaltyCount - penaltiesApplied;

                if (penaltiesToAdd > 0)
                {
                    for (int i = 0; i < penaltiesToAdd; i++)
                    {
                        occurrence.PenaltyCount++;
                        await _karmaService.AddKarmaTransactionAsync(
                            occurrence.Chore.HouseId,
                            occurrence.Chore.SeasonId,
                            occurrence.AssignedUserId.Value,
                            -PenaltyConstants.SinglePenalty,
                            KarmaTransactionType.PENALTY,
                            occurrence.Id,
                            cancellationToken
                        );
                    }

                    // Update Status
                    if (occurrence.PenaltyCount >= PenaltyConstants.MaxPenaltyCount)
                    {
                        occurrence.Status = ChoreOccurrenceStatus.CRITICAL_OVERDUE;
                        await _eventPublisher.PublishAsync(new ChoreOverdueEvent(occurrence.Id, occurrence.AssignedUserId.Value, occurrence.Chore.HouseId), cancellationToken);
                    }
                    else if (occurrence.PenaltyCount > 0)
                    {
                        occurrence.Status = ChoreOccurrenceStatus.OVERDUE;
                        await _eventPublisher.PublishAsync(new ChoreOverdueEvent(occurrence.Id, occurrence.AssignedUserId.Value, occurrence.Chore.HouseId), cancellationToken);
                    }

                    _unitOfWork.ChoreOccurrences.Update(occurrence);
                    await _unitOfWork.SaveChangesAsync(cancellationToken);
                    await _unitOfWork.CommitTransactionAsync(cancellationToken);
                    
                    _logger.LogInformation($"Processed penalties for Occurrence {occurrence.Id}. Added {penaltiesToAdd} penalties.");
                }
                else
                {
                    await _unitOfWork.RollbackTransactionAsync(cancellationToken);
                }
            }
            catch (Exception ex)
            {
                await _unitOfWork.RollbackTransactionAsync(cancellationToken);
                _logger.LogError(ex, $"Error processing penalty for Occurrence {occurrence.Id}.");
            }
        }

        _logger.LogInformation("Completed ProcessOverduePenaltiesAsync.");
    }
}
