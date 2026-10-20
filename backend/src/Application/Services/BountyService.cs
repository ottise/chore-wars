using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Bounty;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces;

namespace ChoreWars.Application.Services;

public class BountyService : IBountyService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IEventPublisher _eventPublisher;
    private readonly IOverduePenaltyService? _penalties;

    public BountyService(IUnitOfWork unitOfWork, IMapper mapper, IEventPublisher eventPublisher, IHouseMutationCoordinator? mutationCoordinator = null, TimeProvider? clock = null, IOverduePenaltyService? penalties = null)
    {
        _clock = clock ?? TimeProvider.System;
        _mutations = mutationCoordinator;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _eventPublisher = eventPublisher;
        _penalties = penalties;
    }

    public async Task<BountyResponse> CreateBountyAsync(Guid houseId, CreateBountyRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await CreateBountyCoreAsync(houseId, request, userId, cancellationToken);

        return await _mutations.RunAsync(houseId, () => CreateBountyCoreAsync(houseId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task<BountyResponse> CreateBountyCoreAsync(Guid houseId, CreateBountyRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        await EnsureHouseMemberAsync(houseId, userId, cancellationToken);
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(request.ChoreOccurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), request.ChoreOccurrenceId);

        var season = await _unitOfWork.Seasons.GetByIdAsync(occurrence.SeasonId,cancellationToken);
        if (season == null || season.Status is SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.CANCELLED || _clock.GetUtcNow().UtcDateTime < season.StartDate)
            throw new ConflictException("Bounties require an approved season that has started.");
        if (occurrence.Chore.HouseId != houseId)
            throw new NotFoundException(nameof(ChoreOccurrence), request.ChoreOccurrenceId);
        if (request.Amount <= 0 || occurrence.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED)
            throw new ConflictException("Bounty requires an unfinished assigned chore and a positive amount.");
        if (occurrence.AssignedUserId != userId)
            throw new ForbiddenException("You can only post a bounty for your own chore.");

        var existingBounty = await _unitOfWork.ChoreBounties.GetByOccurrenceIdAsync(request.ChoreOccurrenceId, cancellationToken);
        if (existingBounty != null && existingBounty.Status != BountyStatus.CANCELLED)
            throw new ConflictException("An active bounty already exists for this chore.");

        var bounty = new ChoreBounty
        {
            Id = Guid.NewGuid(),
            ChoreOccurrenceId = request.ChoreOccurrenceId,
            PostedByUserId = userId,
            Amount = request.Amount,
            Status = BountyStatus.OPEN,
            ExpiresAt = _clock.GetUtcNow().UtcDateTime.AddHours(24),
            CreatedAt = _clock.GetUtcNow().UtcDateTime
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.ChoreBounties.AddAsync(bounty, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        await _eventPublisher.PublishAsync(new BountyCreatedEvent(bounty.Id, houseId), cancellationToken);

        var response = _mapper.Map<BountyResponse>(bounty);
        if (bounty.Status == BountyStatus.EXPIRED)
        {
            var payments = await _unitOfWork.PaymentObligations.GetByHouseIdAsync(houseId, cancellationToken);
            response.ForcedCompensationAmount = payments
                .FirstOrDefault(payment => payment.OccurrenceId == bounty.ChoreOccurrenceId
                    && payment.Reason == PaymentObligationReason.FORCED_REASSIGNMENT)
                ?.Amount;
        }

        return response;
    }

    public async Task AcceptBountyAsync(Guid bountyId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await AcceptBountyCoreAsync(bountyId, userId, cancellationToken); return; }
        var context = await _unitOfWork.ChoreBounties.GetByIdAsync(bountyId, cancellationToken) ?? throw new NotFoundException("Bounty not found.");
        await _mutations.RunAsync(context.ChoreOccurrence.Chore.HouseId, () => AcceptBountyCoreAsync(bountyId, userId, cancellationToken), cancellationToken);
    }

    private async Task AcceptBountyCoreAsync(Guid bountyId, Guid userId, CancellationToken cancellationToken = default)
    {
        var bounty = await _unitOfWork.ChoreBounties.GetByIdAsync(bountyId, cancellationToken);
        if (bounty == null)
            throw new NotFoundException(nameof(ChoreBounty), bountyId);

        if (bounty.Status != BountyStatus.OPEN || bounty.ExpiresAt <= _clock.GetUtcNow().UtcDateTime)
            throw new ConflictException("Bounty is not open.");

        if (bounty.PostedByUserId == userId)
            throw new ConflictException("You cannot accept your own bounty.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(bounty.ChoreOccurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), bounty.ChoreOccurrenceId);

        await EnsureHouseMemberAsync(occurrence.Chore.HouseId, userId, cancellationToken);
        if (occurrence.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED)
            throw new ConflictException("The chore has already ended.");
        if (occurrence.AssignedUserId != bounty.PostedByUserId) throw new ConflictException("The chore responsibility has changed.");
        if (_penalties != null && occurrence.DueDate < _clock.GetUtcNow().UtcDateTime)
            await _penalties.ApplyUntilAsync(occurrence.Id,_clock.GetUtcNow().UtcDateTime,cancellationToken);
        bounty.Status = BountyStatus.CLAIMED;
        await ChoreResponsibilityService.AssignAsync(_unitOfWork, occurrence, userId, "BOUNTY", occurrence.DueDate > _clock.GetUtcNow().UtcDateTime ? occurrence.DueDate : _clock.GetUtcNow().UtcDateTime.AddHours(24), _clock.GetUtcNow().UtcDateTime, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.ChoreBounties.Update(bounty);
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        await _eventPublisher.PublishAsync(new BountyAcceptedEvent(bounty.Id, userId), cancellationToken);
    }

    public async Task<IEnumerable<BountyResponse>> GetBountiesAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        await EnsureHouseMemberAsync(houseId, userId, cancellationToken);

        var bounties = await _unitOfWork.ChoreBounties.GetBountiesByHouseIdAsync(houseId, cancellationToken);
        var responses = _mapper.Map<IEnumerable<BountyResponse>>(bounties).ToList();

        var payments = await _unitOfWork.PaymentObligations.GetByHouseIdAsync(houseId, cancellationToken);
        var compensationByOccurrence = payments
            .Where(p => p.Reason == PaymentObligationReason.FORCED_REASSIGNMENT && p.OccurrenceId.HasValue)
            .ToDictionary(p => p.OccurrenceId!.Value, p => p.Amount);

        foreach (var r in responses)
        {
            if (compensationByOccurrence.TryGetValue(r.ChoreOccurrenceId, out var comp))
            {
                r.ForcedCompensationAmount = comp;
            }
        }

        return responses;
    }

    public async Task<BountyResponse> GetBountyAsync(Guid houseId, Guid bountyId, Guid userId, CancellationToken cancellationToken = default)
    {
        await EnsureHouseMemberAsync(houseId, userId, cancellationToken);

        var bounty = await _unitOfWork.ChoreBounties.GetByIdAsync(bountyId, cancellationToken);
        if (bounty == null || bounty.ChoreOccurrence.Chore.HouseId != houseId)
            throw new NotFoundException(nameof(ChoreBounty), bountyId);

        var response=_mapper.Map<BountyResponse>(bounty);
        var payments=await _unitOfWork.PaymentObligations.GetByHouseIdAsync(houseId,cancellationToken);
        response.ForcedCompensationAmount=payments.FirstOrDefault(p=>p.OccurrenceId==bounty.ChoreOccurrenceId&&p.Reason==PaymentObligationReason.FORCED_REASSIGNMENT)?.Amount;
        return response;
    }

    public async Task<IEnumerable<PaymentObligationResponse>> GetPaymentsAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        await EnsureHouseMemberAsync(houseId, userId, cancellationToken);

        var payments = await _unitOfWork.PaymentObligations.GetByHouseIdAsync(houseId, cancellationToken);
        return payments.Select(MapPayment).ToList();
    }

    public async Task<PaymentObligationResponse> GetPaymentAsync(Guid houseId, Guid paymentId, Guid userId, CancellationToken cancellationToken = default)
    {
        await EnsureHouseMemberAsync(houseId, userId, cancellationToken);

        var payment = await _unitOfWork.PaymentObligations.GetByIdAsync(paymentId, cancellationToken);
        if (payment == null || payment.HouseId != houseId)
            throw new NotFoundException(nameof(PaymentObligation), paymentId);

        return MapPayment(payment);
    }

    private async Task EnsureHouseMemberAsync(Guid houseId, Guid userId, CancellationToken cancellationToken)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();
    }

    private static PaymentObligationResponse MapPayment(PaymentObligation payment)
    {
        return new PaymentObligationResponse
        {
            Id = payment.Id,
            HouseId = payment.HouseId,
            OccurrenceId = payment.OccurrenceId,
            DebtorUserId = payment.DebtorUserId,
            DebtorDisplayName = payment.DebtorUser.DisplayName,
            CreditorUserId = payment.CreditorUserId,
            CreditorDisplayName = payment.CreditorUser.DisplayName,
            Amount = payment.Amount,
            Reason = payment.Reason,
            Status = payment.Status,
            CreatedAt = payment.CreatedAt,
            PaidAt = payment.PaidAt,
            ChoreName = payment.Occurrence?.Chore?.Name
        };
    }

    public async Task SettlePaymentAsync(Guid paymentId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await SettlePaymentCoreAsync(paymentId, userId, cancellationToken); return; }
        var context = await _unitOfWork.PaymentObligations.GetByIdAsync(paymentId, cancellationToken) ?? throw new NotFoundException("Payment not found.");
        await _mutations.RunAsync(context.HouseId, () => SettlePaymentCoreAsync(paymentId, userId, cancellationToken), cancellationToken);
    }

    private async Task SettlePaymentCoreAsync(Guid paymentId, Guid userId, CancellationToken cancellationToken = default)
    {
        var payment = await _unitOfWork.PaymentObligations.GetByIdAsync(paymentId, cancellationToken);
        if (payment == null)
            throw new NotFoundException(nameof(PaymentObligation), paymentId);

        if (payment.CreditorUserId != userId)
            throw new ForbiddenException("Only the creditor can confirm receipt of this payment.");

        await EnsureHouseMemberAsync(payment.HouseId, userId, cancellationToken);
        if (payment.Status == PaymentObligationStatus.PAID) return;
        if (payment.Reason == PaymentObligationReason.FORCED_REASSIGNMENT)
        {
            var occurrence = payment.OccurrenceId.HasValue ? await _unitOfWork.ChoreOccurrences.GetByIdAsync(payment.OccurrenceId.Value, cancellationToken) : null;
            if (occurrence?.Status != ChoreOccurrenceStatus.COMPLETED || occurrence.AssignedUserId != userId)
                throw new ConflictException("Forced compensation is payable only after the beneficiary completes the chore.");
        }
        if (payment.Status != PaymentObligationStatus.PENDING)
            throw new ConflictException("Payment is not pending.");

        payment.Status = PaymentObligationStatus.PAID;
        payment.PaidAt = _clock.GetUtcNow().UtcDateTime;
        payment.ConfirmedByUserId = userId;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.PaymentObligations.Update(payment);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }
}
