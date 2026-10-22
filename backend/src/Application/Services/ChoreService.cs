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

public partial class ChoreService : IChoreService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IEventPublisher _eventPublisher;
    private readonly IOverduePenaltyService? _penalties;
    private readonly IKarmaService _karmaService;
    private readonly IEvidenceService? _evidence;

    public ChoreService(IUnitOfWork unitOfWork, IMapper mapper, IEventPublisher eventPublisher, IKarmaService karmaService, IHouseMutationCoordinator? mutationCoordinator = null, TimeProvider? clock = null, IOverduePenaltyService? penalties = null, IEvidenceService? evidence = null)
    {
        _clock = clock ?? TimeProvider.System; _penalties = penalties;
        _mutations = mutationCoordinator;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _eventPublisher = eventPublisher;
        _karmaService = karmaService;
        _evidence = evidence;
    }

    public async Task<ChoreResponse> CreateChoreAsync(Guid houseId, CreateChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await CreateChoreCoreAsync(houseId, request, userId, cancellationToken);

        return await _mutations.RunAsync(houseId, () => CreateChoreCoreAsync(houseId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task<ChoreResponse> CreateChoreCoreAsync(Guid houseId, CreateChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var houseContext = await _unitOfWork.Houses.GetByIdAsync(houseId,cancellationToken) ?? throw new NotFoundException("Household not found.");
        if (houseContext.IsArchived) throw new ConflictException("Archived households are read-only.");
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can create chores.");

        var activeSeason = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, cancellationToken);
        if (!request.AsRoutine && activeSeason == null)
            throw new ConflictException("Create a season before adding chores.");

        if (!request.AsRoutine && activeSeason != null && activeSeason.Status != SeasonStatus.DRAFT)
            throw new ConflictException("Chore definitions are locked outside DRAFT.");
        if (!request.AsRoutine && activeSeason != null) {
            if (await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(activeSeason.Id,cancellationToken))
                await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(activeSeason.Id,cancellationToken);
            activeSeason.ScheduleRevision++; _unitOfWork.Seasons.Update(activeSeason);
        }
        var chore = new Chore
        {
            Id = Guid.NewGuid(),
            HouseId = houseId,
            SeasonId = request.AsRoutine ? null : activeSeason?.Id,
            Name = request.Name,
            Description = request.Description,
            KarmaPoints = request.KarmaPoints,
            Type = request.Type,
            FrequencyType = request.FrequencyType,
            FrequencyValue = request.FrequencyValue,
            Difficulty = request.Difficulty,
            EstimatedMinutes = ScheduleTime.Effort(request.Difficulty),
            DeadlineMinutes = request.DeadlineMinutes, RecurrenceAnchor = request.RecurrenceAnchor, CustomDates = request.CustomDates.ToList()
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Chores.AddAsync(chore, cancellationToken);

            if (request.FrequencyDays != null)
            {
                foreach (var day in request.FrequencyDays.Distinct())
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

    public async Task CompleteChoreAsync(Guid occurrenceId, CompleteChoreRequest? request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await CompleteChoreCoreAsync(occurrenceId, request, userId, cancellationToken); return; }
        var context = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken) ?? throw new NotFoundException("Occurrence not found.");
        await _mutations.RunAsync(context.Chore.HouseId, () => CompleteChoreCoreAsync(occurrenceId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task CompleteChoreCoreAsync(Guid occurrenceId, CompleteChoreRequest? request, Guid userId, CancellationToken cancellationToken = default)
    {
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);

        if (occurrence.AssignedUserId != userId)
            throw new ForbiddenException("Cannot complete a chore assigned to someone else.");

        await EnsureEditableOccurrenceAsync(occurrence, userId, cancellationToken);
        if (occurrence.Status == ChoreOccurrenceStatus.COMPLETED && occurrence.CompletedByUserId == userId) return;
        if (request?.EvidenceId.HasValue==true && !string.IsNullOrWhiteSpace(request.ProofImageUrl)) throw new DomainException("Send EvidenceId or legacy proof, not both.");
        if (occurrence.Status != ChoreOccurrenceStatus.ASSIGNED &&
            occurrence.Status != ChoreOccurrenceStatus.OVERDUE &&
            occurrence.Status != ChoreOccurrenceStatus.CRITICAL_OVERDUE)
            throw new ConflictException("Chore is not in a completable state.");

        if (_penalties != null && occurrence.DueDate < _clock.GetUtcNow().UtcDateTime)
            await _penalties.ApplyUntilAsync(occurrence.Id,_clock.GetUtcNow().UtcDateTime,cancellationToken);
        occurrence.CompletedByUserId = userId;
        occurrence.Status = ChoreOccurrenceStatus.COMPLETED;
        occurrence.CompletedAt = _clock.GetUtcNow().UtcDateTime;

        if (!string.IsNullOrWhiteSpace(request?.ProofImageUrl))
        {
            occurrence.ProofImageUrl = request.ProofImageUrl;
        }

        var chore = await _unitOfWork.Chores.GetByIdAsync(occurrence.ChoreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), occurrence.ChoreId);

        var bounty = await _unitOfWork.ChoreBounties.GetByOccurrenceIdAsync(occurrenceId, cancellationToken);
        PaymentObligation? payment = null;
        if (bounty?.Status == BountyStatus.OPEN) { bounty.Status = BountyStatus.CANCELLED; _unitOfWork.ChoreBounties.Update(bounty); }

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
                CreatedAt = _clock.GetUtcNow().UtcDateTime,
                SeasonId = occurrence.SeasonId,
                OccurrenceId = occurrenceId
            };
        }

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            var responsibility = await ChoreResponsibilityService.EnsureAsync(_unitOfWork, occurrence, _clock.GetUtcNow().UtcDateTime, cancellationToken);
            if (request?.EvidenceId.HasValue==true) {
                if (_evidence==null) throw new ConflictException("Evidence storage is not configured.");
                await _evidence.AttachAsync(occurrenceId,request.EvidenceId.Value,userId,cancellationToken);
            }
            responsibility.EndedAt = _clock.GetUtcNow().UtcDateTime;
            responsibility.CompletedByUserId = userId;
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            var transactionType = chore.Type == ChoreType.BONUS
                ? KarmaTransactionType.BONUS
                : KarmaTransactionType.CHORE_COMPLETED;
            var karmaAmount = occurrence.IsForcedReassigned
                ? 0
                : occurrence.SnapshotKarma;

            // A zero-point forced completion still counts as completed work in
            // ranking tie-breaks and keeps a unique completion audit reference.
            if (karmaAmount >= 0)
            {
                await _karmaService.AddKarmaTransactionAsync(chore.HouseId, occurrence.SeasonId, userId, karmaAmount, transactionType, occurrenceId, cancellationToken);
            }

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

    public Task SkipChoreAsync(Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default)
        => throw new ConflictException("Use a Chore Pass or bounty to transfer responsibility. Direct skipping is not allowed.");

    public async Task<IEnumerable<ChoreOccurrenceResponse>> GetMyChoresAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var occurrences = await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(userId, cancellationToken);
        var houseOccurrences = occurrences.Where(o => o.Chore != null && o.Chore.HouseId == houseId);
        return _mapper.Map<IEnumerable<ChoreOccurrenceResponse>>(houseOccurrences);
    }

    public async Task<ChoreOccurrenceResponse> GetOccurrenceAsync(Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default)
    {
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(
            occurrence.Chore.HouseId,
            userId,
            cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        return _mapper.Map<ChoreOccurrenceResponse>(occurrence);
    }

    public async Task<ChoreResponse> UpdateChoreAsync(Guid choreId, UpdateChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await UpdateChoreCoreAsync(choreId, request, userId, cancellationToken);
        var context = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken) ?? throw new NotFoundException("Chore not found.");
        return await _mutations.RunAsync(context.HouseId, () => UpdateChoreCoreAsync(choreId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task<ChoreResponse> UpdateChoreCoreAsync(Guid choreId, UpdateChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var chore = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), choreId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can update chores.");

        await EnsureDraftChoreAsync(chore, cancellationToken);
        chore.DeadlineMinutes = request.DeadlineMinutes;
        chore.RecurrenceAnchor = request.RecurrenceAnchor;
        chore.CustomDates = request.CustomDates.ToList();
        chore.Difficulty = request.Difficulty;
        chore.EstimatedMinutes = ScheduleTime.Effort(request.Difficulty);
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
            chore.FrequencyDays.Clear();

            if (request.FrequencyDays != null)
            {
                foreach (var day in request.FrequencyDays.Distinct())
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
        if (_mutations == null) { await DeleteChoreCoreAsync(choreId, userId, cancellationToken); return; }
        var context = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken) ?? throw new NotFoundException("Chore not found.");
        await _mutations.RunAsync(context.HouseId, () => DeleteChoreCoreAsync(choreId, userId, cancellationToken), cancellationToken);
    }

    private async Task DeleteChoreCoreAsync(Guid choreId, Guid userId, CancellationToken cancellationToken = default)
    {
        var chore = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), choreId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can delete chores.");

        await EnsureDraftChoreAsync(chore, cancellationToken);
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
        var season = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, cancellationToken);
        if (season == null) return Array.Empty<ChoreResponse>();
        var chores = await _unitOfWork.Chores.GetBySeasonIdAsync(season.Id, cancellationToken);
        return _mapper.Map<IEnumerable<ChoreResponse>>(chores);
    }

    public async Task AssignChoreAsync(Guid choreId, AssignChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await AssignChoreCoreAsync(choreId, request, userId, cancellationToken); return; }
        var context = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken) ?? throw new NotFoundException("Chore not found.");
        await _mutations.RunAsync(context.HouseId, () => AssignChoreCoreAsync(choreId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task AssignChoreCoreAsync(Guid choreId, AssignChoreRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var chore = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
        if (chore == null)
            throw new NotFoundException(nameof(Chore), choreId);

        var requestor = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, userId, cancellationToken);
        if (requestor == null || requestor.Status != HouseMemberStatus.ACTIVE || requestor.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can manually assign chores.");

        var assignee = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(chore.HouseId, request.UserId, cancellationToken);
        if (assignee == null || assignee.Status != HouseMemberStatus.ACTIVE)
            throw new ConflictException("Assignee is not a member of the house.");

        var activeSeason = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(chore.HouseId, cancellationToken);
        if (activeSeason == null)
            throw new ConflictException("No active season in this house.");

        if (activeSeason.Status != SeasonStatus.DRAFT || chore.SeasonId != activeSeason.Id)
            throw new ConflictException("Manual assignment is only allowed for this season's draft schedule.");
        if (!request.OccurrenceId.HasValue)
            throw new ConflictException("Select an existing generated occurrence before assigning this chore.");
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(request.OccurrenceId.Value, cancellationToken)
            ?? throw new NotFoundException("Occurrence not found.");
        if (occurrence.ChoreId != choreId || occurrence.SeasonId != activeSeason.Id)
            throw new ConflictException("Occurrence does not belong to this chore and draft season.");
        if (chore.Type != ChoreType.NORMAL)
            throw new ConflictException("Bonus chores must be claimed after the season starts.");
        occurrence.AssignedUserId = request.UserId;
        occurrence.PlannedStartAt = null;
        activeSeason.ScheduleRevision++;
        _unitOfWork.Seasons.Update(activeSeason);
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
    private async Task EnsureDraftChoreAsync(Chore chore, CancellationToken ct)
    {
        if (chore.SeasonId.HasValue) {
            var season = await _unitOfWork.Seasons.GetByIdAsync(chore.SeasonId.Value, ct);
            if (season?.Status != SeasonStatus.DRAFT) throw new ConflictException("Chore definitions are locked outside draft.");
            if (await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(chore.SeasonId.Value, ct))
                await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(chore.SeasonId.Value, ct);
            season.ScheduleRevision++; _unitOfWork.Seasons.Update(season);
        }
    }
    private async Task EnsureEditableOccurrenceAsync(ChoreOccurrence occurrence, Guid userId, CancellationToken ct)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(occurrence.SeasonId, ct) ?? throw new NotFoundException("Season not found.");
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, ct);
        if (member?.Status != HouseMemberStatus.ACTIVE) throw new ForbiddenException();
        if (season.Status is SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.CANCELLED || _clock.GetUtcNow().UtcDateTime < season.StartDate)
            throw new ConflictException("Work cannot be completed before the approved season starts.");
    }
}
