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

    public OverduePenaltyService(
        IUnitOfWork unitOfWork,
        ILogger<OverduePenaltyService> logger,
        IEventPublisher eventPublisher)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
        _eventPublisher = eventPublisher;
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

                int penaltiesToAdd = expectedPenaltyCount - occurrence.PenaltyCount;

                if (penaltiesToAdd > 0)
                {
                    for (int i = 0; i < penaltiesToAdd; i++)
                    {
                        occurrence.PenaltyCount++;

                        var karmaTransaction = new KarmaTransaction
                        {
                            Id = Guid.NewGuid(),
                            HouseId = occurrence.Chore.HouseId,
                            UserId = occurrence.AssignedUserId.Value,
                            Amount = -PenaltyConstants.SinglePenalty,
                            Type = KarmaTransactionType.PENALTY,
                            ReferenceId = occurrence.Id,
                            CreatedAt = now
                        };

                        await _unitOfWork.KarmaTransactions.AddAsync(karmaTransaction, cancellationToken);
                        
                        var houseMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(occurrence.Chore.HouseId, occurrence.AssignedUserId.Value, cancellationToken);
                        if (houseMember != null)
                        {
                            houseMember.KarmaBalance -= PenaltyConstants.SinglePenalty;
                            _unitOfWork.HouseMembers.Update(houseMember);
                        }
                    }

                    // Update Status
                    if (occurrence.PenaltyCount == 1)
                    {
                        occurrence.Status = ChoreOccurrenceStatus.OVERDUE;
                        await _eventPublisher.PublishAsync(new ChoreOverdueEvent(occurrence.Id, occurrence.AssignedUserId.Value, occurrence.Chore.HouseId), cancellationToken);
                    }
                    else if (occurrence.PenaltyCount >= PenaltyConstants.MaxPenaltyCount)
                    {
                        occurrence.Status = ChoreOccurrenceStatus.CRITICAL_OVERDUE;
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
