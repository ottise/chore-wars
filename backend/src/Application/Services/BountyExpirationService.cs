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

public class BountyExpirationService : IBountyExpirationService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<BountyExpirationService> _logger;
    private readonly IEventPublisher _eventPublisher;

    public BountyExpirationService(
        IUnitOfWork unitOfWork,
        ILogger<BountyExpirationService> logger,
        IEventPublisher eventPublisher)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
        _eventPublisher = eventPublisher;
    }

    public async Task ProcessExpiredBountiesAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting ProcessExpiredBountiesAsync.");

        var now = DateTime.UtcNow;
        var expiredBounties = await _unitOfWork.ChoreBounties.GetExpiredEligibleBountiesAsync(now, cancellationToken);

        foreach (var bounty in expiredBounties)
        {
            try
            {
                await _unitOfWork.BeginTransactionAsync(cancellationToken);

                // Mark bounty as expired
                bounty.Status = BountyStatus.EXPIRED;
                _unitOfWork.ChoreBounties.Update(bounty);

                // Fairness-based reassignment
                var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(bounty.ChoreOccurrence.Chore.HouseId, cancellationToken);
                
                // Exclude the poster from reassignment pool
                var eligibleMembers = members.Where(m => m.UserId != bounty.PostedByUserId).ToList();

                if (eligibleMembers.Any())
                {
                    // Sort by lowest KarmaBalance, then random
                    var assignee = eligibleMembers
                        .OrderBy(m => m.KarmaBalance)
                        .ThenBy(x => Guid.NewGuid())
                        .First();

                    // Update the ChoreOccurrence to the new assignee
                    var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(bounty.ChoreOccurrenceId, cancellationToken);
                    if (occurrence != null)
                    {
                        occurrence.AssignedUserId = assignee.UserId;
                        occurrence.IsForcedReassigned = true;
                        _unitOfWork.ChoreOccurrences.Update(occurrence);
                    }

                    // Create PaymentObligation at 120%
                    var obligation = new PaymentObligation
                    {
                        Id = Guid.NewGuid(),
                        DebtorUserId = bounty.PostedByUserId,
                        CreditorUserId = assignee.UserId,
                        HouseId = bounty.ChoreOccurrence.Chore.HouseId,
                        Amount = bounty.Amount * BountyConstants.ForcedReassignmentMultiplier,
                        Reason = PaymentObligationReason.FORCED_REASSIGNMENT,
                        Status = PaymentObligationStatus.PENDING,
                        CreatedAt = now
                    };
                    
                    await _unitOfWork.PaymentObligations.AddAsync(obligation, cancellationToken);
                }

                await _unitOfWork.SaveChangesAsync(cancellationToken);
                await _unitOfWork.CommitTransactionAsync(cancellationToken);

                // Publish Event
                await _eventPublisher.PublishAsync(new BountyExpiredEvent(bounty.Id, bounty.ChoreOccurrenceId), cancellationToken);

                _logger.LogInformation($"Processed expired bounty {bounty.Id}");
            }
            catch (Exception ex)
            {
                await _unitOfWork.RollbackTransactionAsync(cancellationToken);
                _logger.LogError(ex, $"Error processing expired bounty {bounty.Id}.");
            }
        }

        _logger.LogInformation("Completed ProcessExpiredBountiesAsync.");
    }
}
