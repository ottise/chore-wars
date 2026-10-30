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
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("Only active house members can create chores.");

        // Scope the idempotency key to this actor and house. The primary key and
        // house mutation lock protect retries without a separate request table.
        var choreId = request.ClientRequestId.HasValue
            ? new Guid(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes($"chore:{houseId}:{userId}:{request.ClientRequestId}")).AsSpan(0, 16))
            : Guid.NewGuid();
        if (request.ClientRequestId.HasValue) {
            var prior = await _unitOfWork.Chores.GetByIdAsync(choreId, cancellationToken);
            if (prior != null) {
                if (prior.Name != request.Name || prior.Description != request.Description || prior.Type != request.Type
                    || prior.KarmaPoints != request.KarmaPoints || prior.Difficulty != request.Difficulty
                    || prior.FrequencyType != request.FrequencyType || prior.FrequencyValue != request.FrequencyValue
                    || prior.DeadlineMinutes != request.DeadlineMinutes || prior.RecurrenceAnchor != request.RecurrenceAnchor
                    || prior.SourceTemplateId != request.SourceTemplateId
                    || !prior.CustomDates.Order().SequenceEqual(request.CustomDates.Order())
                    || !prior.FrequencyDays.Select(d => d.DayOfWeek).Distinct().Order().SequenceEqual((request.FrequencyDays ?? []).Distinct().Order()))
                    throw new ConflictException("This create request was already used with different chore details. Reopen the form to create another chore.");
                return await CreationResultAsync(prior, cancellationToken);
            }
        }

        var activeSeason = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason == null || activeSeason.Status is not (SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.ACTIVE))
            throw new ConflictException("Create a draft, reviewing, or active season before adding chores.");
        if (request.ExpectedRevision.HasValue && request.ExpectedRevision != activeSeason.ScheduleRevision)
            throw new ConflictException("The schedule changed. Refresh and try again.");
        Chore? sourceSnapshot = null;
        if (request.SourceTemplateId.HasValue) {
            var source = await _unitOfWork.Chores.GetByIdAsync(request.SourceTemplateId.Value, cancellationToken);
            if (source?.HouseId != houseId || source.SeasonId != null) throw new NotFoundException("Routine not found.");
            var mapped = (await _unitOfWork.Chores.GetBySeasonIdAsync(activeSeason.Id, cancellationToken))
                .FirstOrDefault(c => c.SourceTemplateId == source.Id);
            if (mapped != null) {
                if ((await _unitOfWork.ChoreOccurrences.GetByChoreIdAsync(mapped.Id, cancellationToken)).Any())
                    return await CreationResultAsync(mapped, cancellationToken);
                sourceSnapshot = mapped;
            }
        }
        var chore = sourceSnapshot ?? new Chore
        {
            Id = choreId,
            HouseId = houseId,
            SeasonId = activeSeason.Id,
            SourceTemplateId = request.SourceTemplateId,
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

        if (sourceSnapshot == null)
            chore.FrequencyDays = (request.FrequencyDays ?? []).Distinct().Select(day => new ChoreFrequencyDay {
                Id = Guid.NewGuid(), ChoreId = chore.Id, DayOfWeek = day
            }).ToList();
        var now = _clock.GetUtcNow().UtcDateTime;
        var occurrences = ChoreGenerationService.BuildOccurrences(chore, activeSeason)
            .Where(o => activeSeason.Status != SeasonStatus.ACTIVE || o.DueDate > now).ToList();
        if (occurrences.Count == 0) throw new ConflictException("No future chore dates fit this season. Choose dates within the season or create a new season.");
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            if (sourceSnapshot == null) await _unitOfWork.Chores.AddAsync(chore, cancellationToken);
            var existing = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(activeSeason.Id, cancellationToken)).ToList();
            await AssignNewOccurrencesAsync(activeSeason, occurrences, existing, cancellationToken);
            await _unitOfWork.ChoreOccurrences.AddRangeAsync(occurrences, cancellationToken);
            activeSeason.ScheduleRevision++;
            // Confirmations are bound to ScheduleRevision; previous approvals no
            // longer approve a reviewing schedule after this addition.
            _unitOfWork.Seasons.Update(activeSeason);
            if (activeSeason.Status == SeasonStatus.REVIEWING) {
                await ScheduleReviewRevision.ResetAsync(_unitOfWork, activeSeason, now, cancellationToken);
            }
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return await CreationResultAsync(chore, cancellationToken);
    }

    private async Task<ChoreResponse> CreationResultAsync(Chore chore, CancellationToken ct) {
        var response = _mapper.Map<ChoreResponse>(chore);
        var occurrences = (await _unitOfWork.ChoreOccurrences.GetByChoreIdAsync(chore.Id, ct)).ToList();
        var season = chore.SeasonId.HasValue ? await _unitOfWork.Seasons.GetByIdAsync(chore.SeasonId.Value, ct) : null;
        response.ScheduleRevision = season?.ScheduleRevision ?? 0;
        response.OccurrenceIds = occurrences.Select(o => o.Id).ToList();
        response.AssignmentStatus = occurrences.Count == 0 ? "needs_assignment" : chore.Type == ChoreType.BONUS ? "available_to_claim" : occurrences.Any(o => !o.AssignedUserId.HasValue) ? "needs_assignment" : "assigned";
        if (response.AssignmentStatus == "needs_assignment") response.AssignmentReason = occurrences.Count == 0
            ? "The draft schedule needs to be generated. Ask the owner to review the schedule."
            : season?.AllocationMethod == AllocationMethod.MANUAL ? "This season uses manual assignment. Ask the owner to assign the chore in Team."
            : "No active member has an available slot within workload capacity. Ask the owner to review availability and capacity in Team.";
        return response;
    }

    private async Task AssignNewOccurrencesAsync(ChoreSeason season, List<ChoreOccurrence> added, List<ChoreOccurrence> existing, CancellationToken ct) {
        if (season.AllocationMethod != AllocationMethod.AUTOMATIC) return;
        var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, ct)).Where(m => m.Status == HouseMemberStatus.ACTIVE).ToList();
        var availability = (await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(season.Id, ct)).ToList();
        var exceptions = await _unitOfWork.MemberAvailabilities.GetExceptionsBySeasonAsync(season.Id, ct) ?? [];
        foreach (var occurrence in added.Where(o => o.Chore.Type == ChoreType.NORMAL).OrderBy(o => o.DueDate)) {
            var date = ScheduleTime.Local(occurrence.DueDate);
            var candidates = new List<(Guid User, int Karma, DateTime Start)>();
            foreach (var member in members) {
                var assigned = existing.Concat(added).Where(o => o.AssignedUserId == member.UserId).ToList();
                var limit = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(member.UserId, season.HouseId, ct)
                    ?? new MemberConstraint { MaxChoresPerWeek = AIAllocationConstants.DefaultMaxChoresPerWeek, MaxEffortMinutesPerDay = AIAllocationConstants.DefaultMaxEffortMinutesPerDay };
                if (assigned.Count(o => System.Globalization.ISOWeek.GetYear(ScheduleTime.Local(o.DueDate)) == System.Globalization.ISOWeek.GetYear(date) && System.Globalization.ISOWeek.GetWeekOfYear(ScheduleTime.Local(o.DueDate)) == System.Globalization.ISOWeek.GetWeekOfYear(date)) >= limit.MaxChoresPerWeek) continue;
                if (assigned.Where(o => ScheduleTime.Local(o.DueDate).Date == date.Date).Sum(AllocationEligibilityService.Minutes) + occurrence.SnapshotMinutes > limit.MaxEffortMinutesPerDay) continue;
                var effective = AllocationEligibilityService.Effective(availability.FirstOrDefault(a => a.UserId == member.UserId && a.DayOfWeek == date.DayOfWeek), member.UserId, DateOnly.FromDateTime(date), exceptions);
                var start = AllocationEligibilityService.FindStart(occurrence, effective, assigned, season.Status == SeasonStatus.ACTIVE ? _clock.GetUtcNow().UtcDateTime : season.StartDate);
                if (start.HasValue) candidates.Add((member.UserId, assigned.Sum(o => o.SnapshotKarma), start.Value));
            }
            if (candidates.Count == 0) continue;
            var selected = candidates.OrderBy(c => c.Karma).ThenBy(c => c.User).First();
            occurrence.AssignedUserId = selected.User;
            occurrence.PlannedStartAt = selected.Start;
        }
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

        var response = _mapper.Map<ChoreOccurrenceResponse>(occurrence);
        var season = await _unitOfWork.Seasons.GetByIdAsync(occurrence.SeasonId, cancellationToken);
        var house = await _unitOfWork.Houses.GetByIdAsync(occurrence.Chore.HouseId, cancellationToken);
        response.SeasonName = season?.Name ?? string.Empty;
        var editable = house?.IsArchived == false && season != null
            && season.Status is SeasonStatus.ACTIVE or SeasonStatus.COMPLETED
            && _clock.GetUtcNow().UtcDateTime >= season.StartDate
            && occurrence.AssignedUserId == userId;
        response.CanComplete = editable && occurrence.Status is ChoreOccurrenceStatus.ASSIGNED or ChoreOccurrenceStatus.OVERDUE or ChoreOccurrenceStatus.CRITICAL_OVERDUE;
        response.CanUploadEvidence = editable && occurrence.Status != ChoreOccurrenceStatus.SKIPPED
            && (occurrence.Status != ChoreOccurrenceStatus.COMPLETED || occurrence.CompletedByUserId == userId);
        return response;
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
        var house = await _unitOfWork.Houses.GetByIdAsync(season.HouseId, ct);
        if (house?.IsArchived == true) throw new ConflictException("Archived households are read-only.");
        if (season.Status is SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.CANCELLED || _clock.GetUtcNow().UtcDateTime < season.StartDate)
            throw new ConflictException("Work cannot be completed before the approved season starts.");
    }
}
