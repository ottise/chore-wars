using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class KarmaService : IKarmaService
{
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;

    public KarmaService(IUnitOfWork unitOfWork, TimeProvider? clock = null)
    {
        _clock = clock ?? TimeProvider.System;
        _unitOfWork = unitOfWork;
    }

    /// <summary>
    /// Adds a karma transaction and updates the member's balance. 
    /// Note: The caller is responsible for calling _unitOfWork.SaveChangesAsync() and managing the transaction.
    /// </summary>
    public async Task AddKarmaTransactionAsync(Guid houseId, Guid seasonId, Guid userId, int amount, KarmaTransactionType type, Guid? referenceId = null, CancellationToken cancellationToken = default, DateTime? effectiveAt = null, int? penaltyStep = null)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new NotFoundException(nameof(HouseMember), userId);

        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null || season.HouseId != houseId) throw new NotFoundException(nameof(ChoreSeason), seasonId);
        if (season.Status != SeasonStatus.ACTIVE || (effectiveAt ?? _clock.GetUtcNow().UtcDateTime) < season.StartDate || (effectiveAt ?? _clock.GetUtcNow().UtcDateTime) > season.EndDate)
            return; // Late work is recorded without changing the season ledger.
        // Update balance (can be negative)
        member.KarmaBalance += amount;
        _unitOfWork.HouseMembers.Update(member);

        var transaction = new KarmaTransaction
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            HouseId = houseId,
            SeasonId = seasonId,
            Amount = amount, PenaltyStep = penaltyStep,
            Type = type,
            ReferenceId = referenceId,
            CreatedAt = effectiveAt ?? _clock.GetUtcNow().UtcDateTime
        };

        await _unitOfWork.KarmaTransactions.AddAsync(transaction, cancellationToken);
    }
}
