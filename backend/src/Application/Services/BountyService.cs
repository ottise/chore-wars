using System;
using System.Collections.Generic;
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
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IEventPublisher _eventPublisher;

    public BountyService(IUnitOfWork unitOfWork, IMapper mapper, IEventPublisher eventPublisher)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _eventPublisher = eventPublisher;
    }

    public async Task<BountyResponse> CreateBountyAsync(Guid houseId, CreateBountyRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(request.ChoreOccurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), request.ChoreOccurrenceId);

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
            ExpiresAt = occurrence.DueDate, // Bounty expires when chore is due
            CreatedAt = DateTime.UtcNow
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

        return _mapper.Map<BountyResponse>(bounty);
    }

    public async Task AcceptBountyAsync(Guid bountyId, Guid userId, CancellationToken cancellationToken = default)
    {
        var bounty = await _unitOfWork.ChoreBounties.GetByIdAsync(bountyId, cancellationToken);
        if (bounty == null)
            throw new NotFoundException(nameof(ChoreBounty), bountyId);

        if (bounty.Status != BountyStatus.OPEN)
            throw new ConflictException("Bounty is not open.");

        if (bounty.PostedByUserId == userId)
            throw new ConflictException("You cannot accept your own bounty.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(bounty.ChoreOccurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), bounty.ChoreOccurrenceId);
        
        bounty.Status = BountyStatus.CLAIMED;
        occurrence.AssignedUserId = userId; // Reassign chore

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
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var bounties = await _unitOfWork.ChoreBounties.GetActiveBountiesByHouseIdAsync(houseId, cancellationToken);
        return _mapper.Map<IEnumerable<BountyResponse>>(bounties);
    }

    public async Task SettlePaymentAsync(Guid paymentId, Guid userId, CancellationToken cancellationToken = default)
    {
        var payment = await _unitOfWork.PaymentObligations.GetByIdAsync(paymentId, cancellationToken);
        if (payment == null)
            throw new NotFoundException(nameof(PaymentObligation), paymentId);

        if (payment.FromUserId != userId)
            throw new ForbiddenException("Only the payer can settle the payment.");

        if (payment.Status != PaymentObligationStatus.PENDING)
            throw new ConflictException("Payment is not pending.");

        payment.Status = PaymentObligationStatus.PAID;

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
