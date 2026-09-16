using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces;
using System.Linq;

namespace ChoreWars.Application.Services;

public class ChoreService : IChoreService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IEventPublisher _eventPublisher;
    private readonly IKarmaService _karmaService;

    public ChoreService(IUnitOfWork unitOfWork, IMapper mapper, IEventPublisher eventPublisher, IKarmaService karmaService)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _eventPublisher = eventPublisher;
        _karmaService = karmaService;
    }

    public async Task<ChoreResponse> CreateChoreAsync(Guid houseId, CreateChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only house owners can create chores.");

        var activeSeason = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason == null)
            throw new ConflictException("No active season to add chore to.");

        var chore = new Chore
        {
            Id = Guid.NewGuid(),
            HouseId = houseId,
            SeasonId = activeSeason.Id,
            Name = request.Name,
            Description = request.Description,
            KarmaPoints = request.KarmaPoints,
            Type = request.Type,
            FrequencyType = request.FrequencyType,
            FrequencyValue = request.FrequencyValue
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Chores.AddAsync(chore, cancellationToken);
            
            if (request.FrequencyType == FrequencyType.SPECIFIC_DAYS && request.FrequencyDays != null)
            {
                foreach (var day in request.FrequencyDays)
                {
                    var freqDay = new ChoreFrequencyDay
                    {
                        Id = Guid.NewGuid(),
                        ChoreId = chore.Id,
                        DayOfWeek = day
                    };
                    await _unitOfWork.ChoreFrequencyDays.AddAsync(freqDay, cancellationToken);
                }
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<ChoreResponse>(chore);
    }

    public async Task CompleteChoreAsync(Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default)
    {
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);

        if (occurrence.AssignedUserId != userId)
            throw new ForbiddenException("Cannot complete a chore assigned to someone else.");

        if (occurrence.Status != ChoreOccurrenceStatus.ASSIGNED && 
            occurrence.Status != ChoreOccurrenceStatus.OVERDUE &&
            occurrence.Status != ChoreOccurrenceStatus.CRITICAL_OVERDUE)
            throw new ConflictException("Chore is not in a completable state.");

        occurrence.Status = ChoreOccurrenceStatus.COMPLETED;
        occurrence.CompletedAt = DateTime.UtcNow;

        var chore = await _unitOfWork.Chores.GetByIdAsync(occurrence.ChoreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), occurrence.ChoreId);

        var bounty = await _unitOfWork.ChoreBounties.GetByOccurrenceIdAsync(occurrenceId, cancellationToken);
        PaymentObligation? payment = null;

        if (bounty != null && bounty.Status == BountyStatus.CLAIMED)
        {
            bounty.Status = BountyStatus.COMPLETED;
            payment = new PaymentObligation
            {
                Id = Guid.NewGuid(),
                HouseId = chore.HouseId,
                DebtorUserId = bounty.PostedByUserId,
                CreditorUserId = userId,
                Amount = bounty.Amount,
                Reason = PaymentObligationReason.BOUNTY_PAYMENT,
                Status = PaymentObligationStatus.PENDING,
                CreatedAt = DateTime.UtcNow,
                SeasonId = chore.SeasonId,
                OccurrenceId = occurrenceId
            };
        }

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            await _karmaService.AddKarmaTransactionAsync(chore.HouseId, chore.SeasonId, userId, chore.KarmaPoints, KarmaTransactionType.CHORE_COMPLETED, occurrenceId, cancellationToken);
            
            if (bounty != null && payment != null)
            {
                _unitOfWork.ChoreBounties.Update(bounty);
                await _unitOfWork.PaymentObligations.AddAsync(payment, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        // Side effects after successful commit
        await _eventPublisher.PublishAsync(new ChoreCompletedEvent(occurrenceId, userId, chore.HouseId), cancellationToken);
    }

    public async Task SkipChoreAsync(Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default)
    {
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);

        var chore = await _unitOfWork.Chores.GetByIdAsync(occurrence.ChoreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), occurrence.ChoreId);
            
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only owner can manually skip a chore (unless using a pass).");

        occurrence.Status = ChoreOccurrenceStatus.SKIPPED;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<ChoreOccurrenceResponse>> GetMyChoresAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var occurrences = await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(userId, cancellationToken);
        var houseOccurrences = occurrences.Where(o => o.Chore != null && o.Chore.HouseId == houseId);
        return _mapper.Map<IEnumerable<ChoreOccurrenceResponse>>(houseOccurrences);
    }

    public async Task<ChoreResponse> UpdateChoreAsync(Guid choreId, UpdateChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var chore = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), choreId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only house owners can update chores.");

        chore.Name = request.Name;
        chore.Description = request.Description;
        chore.KarmaPoints = request.KarmaPoints;
        chore.Type = request.Type;
        chore.FrequencyType = request.FrequencyType;
        chore.FrequencyValue = request.FrequencyValue;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Chores.Update(chore);
            
            await _unitOfWork.ChoreFrequencyDays.DeleteByChoreIdAsync(choreId, cancellationToken);
            
            if (request.FrequencyType == FrequencyType.SPECIFIC_DAYS && request.FrequencyDays != null)
            {
                foreach (var day in request.FrequencyDays)
                {
                    var freqDay = new ChoreFrequencyDay
                    {
                        Id = Guid.NewGuid(),
                        ChoreId = chore.Id,
                        DayOfWeek = day
                    };
                    await _unitOfWork.ChoreFrequencyDays.AddAsync(freqDay, cancellationToken);
                }
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<ChoreResponse>(chore);
    }

    public async Task DeleteChoreAsync(Guid choreId, Guid userId, CancellationToken cancellationToken = default)
    {
        var chore = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), choreId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only house owners can delete chores.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.ChoreFrequencyDays.DeleteByChoreIdAsync(choreId, cancellationToken);
            _unitOfWork.Chores.Delete(chore);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<ChoreResponse>> GetChoresByHouseAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        var activeSeason = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason == null)
            return Array.Empty<ChoreResponse>();

        var chores = await _unitOfWork.Chores.GetBySeasonIdAsync(activeSeason.Id, cancellationToken);
        return _mapper.Map<IEnumerable<ChoreResponse>>(chores);
    }

    public async Task AssignChoreAsync(Guid choreId, AssignChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var chore = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), choreId);

        var requestor = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        if (requestor == null || requestor.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only house owners can manually assign chores.");

        var assignee = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, request.UserId, cancellationToken);
        if (assignee == null)
            throw new ConflictException("Assignee is not a member of the house.");

        var occurrence = new ChoreOccurrence
        {
            Id = Guid.NewGuid(),
            ChoreId = choreId,
            AssignedUserId = request.UserId,
            DueDate = DateTime.UtcNow.Date.AddDays(1), // Basic default for manual assign
            Status = ChoreOccurrenceStatus.ASSIGNED
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.ChoreOccurrences.AddAsync(occurrence, cancellationToken);
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
