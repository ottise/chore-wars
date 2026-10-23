using System.Text.Json;
using System.Text.Json.Serialization;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class ActionProposalService : IActionProposalService
{
    private static readonly JsonSerializerOptions PayloadJsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly bool _mutationsEnabled;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IActionProposalRealtimePublisher _realtimePublisher;
    private readonly INotificationService? _notificationService;
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly IAfterCommitActions? _afterCommit;
    private readonly TimeProvider _clock;

    private readonly IScheduleChangeService? _scheduleChanges;
    private readonly IUrgentPlanValidation? _urgentPlanValidation;
    public ActionProposalService(IUnitOfWork unitOfWork, IActionProposalRealtimePublisher realtimePublisher, bool mutationsEnabled = false,
        INotificationService? notificationService = null, IHouseMutationCoordinator? mutationCoordinator = null,
        IAfterCommitActions? afterCommit = null, TimeProvider? clock = null, IScheduleChangeService? scheduleChanges = null, IUrgentPlanValidation? urgentPlanValidation = null)
    {
        _mutationsEnabled = mutationsEnabled;
        _unitOfWork = unitOfWork;
        _realtimePublisher = realtimePublisher;
        _notificationService = notificationService;
        _mutations = mutationCoordinator;
        _afterCommit = afterCommit;
        _clock = clock ?? TimeProvider.System;
        _scheduleChanges = scheduleChanges;
        _urgentPlanValidation = urgentPlanValidation;
    }

    public async Task<ActionProposalResponse> CreateProposalAsync(
        Guid houseId, CreateProposalRequest request, Guid creatorId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await CreateProposalCoreAsync(houseId, request, creatorId, cancellationToken);
        return await _mutations.RunAsync(houseId, () => CreateProposalCoreAsync(houseId, request, creatorId, cancellationToken), cancellationToken);
    }

    private async Task<ActionProposalResponse> CreateProposalCoreAsync(
        Guid houseId,
        CreateProposalRequest request,
        Guid creatorId,
        CancellationToken cancellationToken = default)
    {
        EnsureMutationsEnabled(request.Type);
        await EnsureHouseWritableAsync(houseId, cancellationToken);
        ValidateCreateRequest(request, creatorId);
        await EnsureActiveMemberAsync(houseId, creatorId, cancellationToken);

        var room = await _unitOfWork.Chats.GetRoomByHouseIdAsync(houseId, cancellationToken)
            ?? throw new NotFoundException("The house chat room does not exist.");

        var targetIds = request.TargetUserIds.Distinct().ToList();
        foreach (var targetId in targetIds)
            await EnsureActiveMemberAsync(houseId, targetId, cancellationToken);

        await ValidatePayloadAsync(houseId, creatorId, request.Type, request.PayloadJson, targetIds, cancellationToken);

        var proposal = new ActionProposal
        {
            Id = Guid.NewGuid(),
            HouseId = houseId,
            RoomId = room.Id,
            CreatorId = creatorId,
            Type = request.Type,
            Status = ProposalStatus.PENDING,
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            PayloadJson = request.PayloadJson,
            CreatedAt = _clock.GetUtcNow().UtcDateTime,
            ExpiresAt = request.ExpiresAt,
            Confirmations = targetIds.Select(targetId => new ProposalConfirmation
            {
                Id = Guid.NewGuid(),
                TargetUserId = targetId,
                Status = ConfirmationStatus.PENDING
            }).ToList()
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.ActionProposals.AddAsync(proposal, cancellationToken);
            if (proposal.Type==ProposalType.SCHEDULE_REPLAN && targetIds.Count==0) {
                await ExecuteApprovedProposalAsync(proposal,cancellationToken);
                proposal.Status=ProposalStatus.APPROVED;
            }
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        var response = Map(proposal);
        if (_afterCommit != null) _afterCommit.Enqueue(() => _realtimePublisher.ProposalCreatedAsync(response, cancellationToken));
        else await _realtimePublisher.ProposalCreatedAsync(response, cancellationToken);
        return response;
    }

    public async Task<ActionProposalResponse> RespondProposalAsync(
        Guid proposalId, RespondProposalRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await RespondProposalCoreAsync(proposalId, request, userId, cancellationToken);
        var context = await _unitOfWork.ActionProposals.GetByIdAsync(proposalId, cancellationToken)
            ?? throw new NotFoundException(nameof(ActionProposal), proposalId);
        return await _mutations.RunAsync(context.HouseId, () => RespondProposalCoreAsync(proposalId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task<ActionProposalResponse> RespondProposalCoreAsync(
        Guid proposalId,
        RespondProposalRequest request,
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        if (request.Status is not (ConfirmationStatus.CONFIRMED or ConfirmationStatus.REJECTED))
            throw new DomainException("A response must be CONFIRMED or REJECTED.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        ActionProposal proposal;
        try
        {
            proposal = await _unitOfWork.ActionProposals.GetByIdForUpdateAsync(proposalId, cancellationToken)
                ?? throw new NotFoundException(nameof(ActionProposal), proposalId);
            EnsureMutationsEnabled(proposal.Type);
            await EnsureHouseWritableAsync(proposal.HouseId, cancellationToken);
            await EnsureActiveMemberAsync(proposal.HouseId, userId, cancellationToken);
            await EnsureActiveMemberAsync(proposal.HouseId, proposal.CreatorId, cancellationToken);

            if (proposal.Status != ProposalStatus.PENDING)
                throw new ConflictException("This proposal is no longer pending.");
            if (proposal.ExpiresAt.HasValue && proposal.ExpiresAt <= _clock.GetUtcNow().UtcDateTime)
                throw new ConflictException("This proposal has expired.");

            var confirmation = proposal.Confirmations.SingleOrDefault(x => x.TargetUserId == userId)
                ?? throw new ForbiddenException("Only a target member can respond to this proposal.");
            if (confirmation.Status != ConfirmationStatus.PENDING)
                throw new ConflictException("You have already responded to this proposal.");

            confirmation.Status = request.Status;
            confirmation.Reason = string.IsNullOrWhiteSpace(request.Reason) ? null : request.Reason.Trim();
            confirmation.RespondedAt = _clock.GetUtcNow().UtcDateTime;

            if (request.Status == ConfirmationStatus.REJECTED)
            {
                proposal.Status = ProposalStatus.REJECTED;
            }
            else if (proposal.Confirmations.All(x => x.Status == ConfirmationStatus.CONFIRMED))
            {
                if (proposal.Type is ProposalType.URGENT_EVENT or ProposalType.SCHEDULE_REPLAN)
                {
                    foreach (var participant in proposal.Confirmations)
                        await EnsureActiveMemberAsync(proposal.HouseId, participant.TargetUserId, cancellationToken);
                    await ValidatePayloadAsync(proposal.HouseId, proposal.CreatorId, proposal.Type, proposal.PayloadJson,
                        proposal.Confirmations.Select(x => x.TargetUserId).ToList(), cancellationToken);
                }
                await ExecuteApprovedProposalAsync(proposal, cancellationToken);
                proposal.Status = ProposalStatus.APPROVED;
            }

            _unitOfWork.ActionProposals.Update(proposal);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        var response = Map(proposal);
        if (_afterCommit != null) _afterCommit.Enqueue(() => _realtimePublisher.ProposalUpdatedAsync(response, cancellationToken));
        else await _realtimePublisher.ProposalUpdatedAsync(response, cancellationToken);

        if (_notificationService != null && proposal.Type == ProposalType.URGENT_EVENT && proposal.Status == ProposalStatus.APPROVED)
        {
            var participantIds = proposal.Confirmations
                .Select(x => x.TargetUserId)
                .Append(proposal.CreatorId)
                .Distinct();
            foreach (var participantId in participantIds)
            {
                await _notificationService.CreateNotificationAsync(
                    participantId,
                    proposal.HouseId,
                    "Urgent campaign started!",
                    $"{proposal.Title} was approved by all required members. The countdown has started.",
                    nameof(NotificationType.URGENT_EVENT),
                    "ActionProposal",
                    proposal.Id,
                    cancellationToken);
            }
        }
        return response;
    }

    public async Task<IReadOnlyList<ActionProposalResponse>> GetActiveProposalsAsync(
        Guid roomId,
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var room = await _unitOfWork.Chats.GetRoomByIdAsync(roomId, cancellationToken)
            ?? throw new NotFoundException(nameof(ChatRoom), roomId);
        await EnsureActiveMemberAsync(room.HouseId, userId, cancellationToken);
        var proposals = await _unitOfWork.ActionProposals.GetActiveByRoomIdAsync(roomId, _clock.GetUtcNow().UtcDateTime, cancellationToken);
        return proposals.Select(Map).ToList();
    }

    private async Task EnsureHouseWritableAsync(Guid houseId, CancellationToken ct)
    {
        if (_mutations == null) return;
        var house = await _unitOfWork.Houses.GetByIdAsync(houseId, ct) ?? throw new NotFoundException("Household not found.");
        if (house.IsArchived) throw new ConflictException("Archived households are read-only.");
    }

    private void EnsureMutationsEnabled(ProposalType type)
    {
        if (!_mutationsEnabled && type == ProposalType.SEASON_APPROVAL)
            throw new ConflictException("Proposal actions are deferred. Use season review for season approvals.");
    }

    private void ValidateCreateRequest(CreateProposalRequest request, Guid creatorId)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
            throw new DomainException("Proposal title is required.");
        if (request.Title.Trim().Length > 150)
            throw new DomainException("Proposal title cannot exceed 150 characters.");
        if (request.Description?.Trim().Length > 1000)
            throw new DomainException("Proposal description cannot exceed 1000 characters.");
        if (request.TargetUserIds.Count == 0 && request.Type != ProposalType.SCHEDULE_REPLAN)
            throw new DomainException("At least one target member is required.");
        if (request.TargetUserIds.Contains(creatorId))
            throw new DomainException("The proposal creator cannot also be a target.");
        if (request.TargetUserIds.Count != request.TargetUserIds.Distinct().Count())
            throw new DomainException("Target members must be unique.");
        if (request.ExpiresAt.HasValue && request.ExpiresAt <= _clock.GetUtcNow().UtcDateTime)
            throw new DomainException("Proposal expiration must be in the future.");
        if (string.IsNullOrWhiteSpace(request.PayloadJson))
            throw new DomainException("Proposal payload is required.");
    }

    private async Task ValidatePayloadAsync(
        Guid houseId,
        Guid creatorId,
        ProposalType type,
        string payloadJson,
        IReadOnlyCollection<Guid> targetIds,
        CancellationToken cancellationToken)
    {
        switch (type)
        {
            case ProposalType.SCHEDULE_REPLAN:
                if (_scheduleChanges==null) throw new ConflictException("Schedule replan is not configured.");
                var replan=Deserialize<ScheduleChangePayload>(payloadJson);
                var approvers=await _scheduleChanges.ValidateAsync(houseId,replan,cancellationToken);
                if (!targetIds.ToHashSet().SetEquals(approvers.Where(id=>id!=creatorId)))
                    throw new DomainException("Replan must be approved by the owner and every old/new assignee.");
                break;
            case ProposalType.CHORE_SWAP:
                if (targetIds.Count != 1)
                    throw new DomainException("A chore swap must have exactly one target member.");
                var swap = Deserialize<ChoreSwapPayload>(payloadJson);
                var source = await GetHouseOccurrenceAsync(swap.SourceOccurrenceId, houseId, cancellationToken);
                var target = await GetHouseOccurrenceAsync(swap.TargetOccurrenceId, houseId, cancellationToken);
                if (source.Id == target.Id)
                    throw new DomainException("A chore cannot be swapped with itself.");
                if (source.AssignedUserId != creatorId || target.AssignedUserId != targetIds.Single())
                    throw new ForbiddenException("The swap occurrences must belong to the creator and target member.");
                if (source.Status != ChoreOccurrenceStatus.ASSIGNED || target.Status != ChoreOccurrenceStatus.ASSIGNED)
                    throw new ConflictException("Only assigned chores can be swapped.");
                await ValidateSwapAsync(source, target, cancellationToken);
                break;

            case ProposalType.URGENT_EVENT:
                var urgent = Deserialize<UrgentEventPayload>(payloadJson);
                if (urgent.DeadlineMinutes is < 1 or > 1440)
                    throw new DomainException("Urgent event deadline must be between 1 and 1440 minutes.");
                if (urgent.Chores == null || urgent.Chores.Count == 0 || urgent.Chores.Count > 20)
                    throw new DomainException("An urgent event must contain at least one chore.");
                if (urgent.Chores.Any(x => x == null || string.IsNullOrWhiteSpace(x.Name) || x.Name.Trim().Length > 100 || (x.Description?.Trim().Length ?? 0) > 500 || x.KarmaPoints < 0 || !Enum.IsDefined(x.Difficulty)))
                    throw new DomainException("Urgent chore name, description, or karma value is invalid.");
                var season = await _unitOfWork.Seasons.GetByIdAsync(urgent.SeasonId, cancellationToken)
                    ?? throw new NotFoundException(nameof(ChoreSeason), urgent.SeasonId);
                if (season.HouseId != houseId)
                    throw new ForbiddenException("The selected season does not belong to this house.");
                if (season.Status != SeasonStatus.ACTIVE)
                    throw new ConflictException("Urgent events can only be created during an active season.");
                if (_clock.GetUtcNow().UtcDateTime >= season.EndDate)
                    throw new ConflictException("This season has reached its cutoff.");
                if (_clock.GetUtcNow().UtcDateTime.AddMinutes(urgent.DeadlineMinutes) > season.EndDate)
                    throw new ConflictException("The urgent deadline must fit inside the active season.");
                var participants = targetIds.Append(creatorId).ToHashSet();
                if (urgent.Chores.Any(x => string.IsNullOrWhiteSpace(x.Name) || !participants.Contains(x.AssignedUserId)))
                    throw new DomainException("Every urgent chore needs a name and an assignee participating in the event.");
                if(urgent.PlanVersion!=null) {
                    if(_urgentPlanValidation==null)throw new ConflictException("Urgent timeline validation is unavailable.");
                    await _urgentPlanValidation.ValidateAsync(houseId,urgent,cancellationToken);
                }
                break;

            case ProposalType.SEASON_APPROVAL:
                JsonDocument.Parse(payloadJson).Dispose();
                break;

            default:
                throw new DomainException("Unsupported proposal type.");
        }
    }

    private async Task ExecuteApprovedProposalAsync(ActionProposal proposal, CancellationToken cancellationToken)
    {
        switch (proposal.Type)
        {
            case ProposalType.SCHEDULE_REPLAN:
                if (_scheduleChanges==null) throw new ConflictException("Schedule replan is not configured.");
                await _scheduleChanges.ApplyAsync(proposal.HouseId,Deserialize<ScheduleChangePayload>(proposal.PayloadJson),cancellationToken);
                break;
            case ProposalType.CHORE_SWAP:
                var swap = Deserialize<ChoreSwapPayload>(proposal.PayloadJson);
                var source = await GetHouseOccurrenceAsync(swap.SourceOccurrenceId, proposal.HouseId, cancellationToken);
                var target = await GetHouseOccurrenceAsync(swap.TargetOccurrenceId, proposal.HouseId, cancellationToken);
                var targetUserId = proposal.Confirmations.Single().TargetUserId;
                if (source.AssignedUserId != proposal.CreatorId || target.AssignedUserId != targetUserId)
                    throw new ConflictException("Chore assignments changed after this swap was proposed.");
                if (source.Status != ChoreOccurrenceStatus.ASSIGNED || target.Status != ChoreOccurrenceStatus.ASSIGNED)
                    throw new ConflictException("Only assigned chores can be swapped.");
                await EnsureActiveMemberAsync(proposal.HouseId, targetUserId, cancellationToken);
                await ValidateSwapAsync(source, target, cancellationToken);
                var sourceStart = await SwapStartAsync(source, target, targetUserId, cancellationToken);
                var targetStart = await SwapStartAsync(target, source, proposal.CreatorId, cancellationToken);
                await ChoreResponsibilityService.AssignAsync(_unitOfWork, source, targetUserId, "SWAP", source.DueDate, _clock.GetUtcNow().UtcDateTime, cancellationToken);
                await ChoreResponsibilityService.AssignAsync(_unitOfWork, target, proposal.CreatorId, "SWAP", target.DueDate, _clock.GetUtcNow().UtcDateTime, cancellationToken);
                source.PlannedStartAt = sourceStart;
                target.PlannedStartAt = targetStart;
                _unitOfWork.ChoreOccurrences.Update(source);
                _unitOfWork.ChoreOccurrences.Update(target);
                break;

            case ProposalType.URGENT_EVENT:
                var urgent = Deserialize<UrgentEventPayload>(proposal.PayloadJson);
                var now = _clock.GetUtcNow().UtcDateTime;
                if(urgent.PlanVersion!=null) {
                    if(_urgentPlanValidation==null)throw new ConflictException("Urgent timeline validation is unavailable.");
                    await _urgentPlanValidation.ValidateAsync(proposal.HouseId,urgent,cancellationToken);
                }
                var dueDate = now.AddMinutes(urgent.DeadlineMinutes);
                var urgentSeason = await _unitOfWork.Seasons.GetByIdAsync(urgent.SeasonId, cancellationToken)
                    ?? throw new NotFoundException(nameof(ChoreSeason), urgent.SeasonId);
                if (dueDate > urgentSeason.EndDate) throw new ConflictException("The urgent deadline must fit inside the active season.");
                // Once approved, ExpiresAt becomes the campaign deadline so
                // clients can keep showing the active countdown banner.
                proposal.ExpiresAt = dueDate;
                foreach (var item in urgent.Chores)
                {
                    var chore = new Chore
                    {
                        Id = Guid.NewGuid(),
                        HouseId = proposal.HouseId,
                        SeasonId = urgent.SeasonId,
                        Name = item.Name.Trim(),
                        Description = item.Description?.Trim() ?? string.Empty,
                        KarmaPoints = item.KarmaPoints,
                        Type = ChoreType.NORMAL,
                        FrequencyType = FrequencyType.CUSTOM,
                        Difficulty = item.Difficulty,
                        EstimatedMinutes = ScheduleTime.Effort(item.Difficulty)
                    };
                    await _unitOfWork.Chores.AddAsync(chore, cancellationToken);
                    await _unitOfWork.ChoreOccurrences.AddAsync(new ChoreOccurrence
                    {
                        Id = Guid.NewGuid(),
                        ChoreId = chore.Id,
                        SeasonId = urgent.SeasonId,
                        AssignedUserId = item.AssignedUserId,
                        PlannedStartAt = urgent.PlanVersion==null?null:now.AddMinutes(item.PlannedOffsetMinutes),
                        DueDate = dueDate,
                        Status = ChoreOccurrenceStatus.ASSIGNED,
                        SnapshotKarma = item.KarmaPoints,
                        SnapshotMinutes = ScheduleTime.Effort(item.Difficulty),
                        SnapshotDifficulty = item.Difficulty
                    }, cancellationToken);
                }
                break;

            case ProposalType.SEASON_APPROVAL:
                // Season lifecycle changes belong to SeasonService. The proposal only records consensus.
                break;
        }
    }

    private async Task<ChoreOccurrence> GetHouseOccurrenceAsync(Guid occurrenceId, Guid houseId, CancellationToken cancellationToken)
    {
        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken)
            ?? throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);
        if (occurrence.Chore.HouseId != houseId)
            throw new ForbiddenException("The chore occurrence does not belong to this house.");
        return occurrence;
    }

    private async Task ValidateSwapAsync(ChoreOccurrence source, ChoreOccurrence target, CancellationToken ct)
    {
        var now = _clock.GetUtcNow().UtcDateTime;
        if (source.SeasonId != target.SeasonId || source.Chore.Type != ChoreType.NORMAL || target.Chore.Type != ChoreType.NORMAL ||
            source.DueDate <= now || target.DueDate <= now || source.IsForcedReassigned || target.IsForcedReassigned)
            throw new ConflictException("Swap requires two unexpired normal chores in the same active season.");
        var season = await _unitOfWork.Seasons.GetByIdAsync(source.SeasonId, ct);
        if (season?.Status != SeasonStatus.ACTIVE || season.EndDate <= now)
            throw new ConflictException("Swaps require an active season before its cutoff.");
        var payments = await _unitOfWork.PaymentObligations.GetByHouseIdAsync(source.Chore.HouseId, ct);
        foreach (var occurrence in new[] { source, target })
            if (await _unitOfWork.ChoreBounties.GetByOccurrenceIdAsync(occurrence.Id, ct) != null || payments.Any(p => p.OccurrenceId == occurrence.Id))
                throw new ConflictException("Chores linked to a bounty or payment cannot be swapped.");
        await SwapStartAsync(source, target, target.AssignedUserId!.Value, ct);
        await SwapStartAsync(target, source, source.AssignedUserId!.Value, ct);
    }

    private async Task<DateTime> SwapStartAsync(ChoreOccurrence incoming, ChoreOccurrence outgoing, Guid assignee, CancellationToken ct)
    {
        var assigned = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(incoming.SeasonId, ct))
            .Where(o => o.AssignedUserId == assignee && o.Id != outgoing.Id && o.Id != incoming.Id && o.Chore.Type == ChoreType.NORMAL).ToList();
        var limit = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(assignee, incoming.Chore.HouseId, ct);
        var day = ScheduleTime.Local(incoming.DueDate);
        var week = System.Globalization.ISOWeek.GetWeekOfYear(day);
        var year = System.Globalization.ISOWeek.GetYear(day);
        if (assigned.Count(o => System.Globalization.ISOWeek.GetYear(ScheduleTime.Local(o.DueDate)) == year && System.Globalization.ISOWeek.GetWeekOfYear(ScheduleTime.Local(o.DueDate)) == week) >= (limit?.MaxChoresPerWeek ?? 20) ||
            assigned.Where(o => ScheduleTime.Local(o.DueDate).Date == day.Date).Sum(AllocationEligibilityService.Minutes) + AllocationEligibilityService.Minutes(incoming) > (limit?.MaxEffortMinutesPerDay ?? 120))
            throw new ConflictException("The proposed swap exceeds workload limits.");
        var available = (await _unitOfWork.MemberAvailabilities.GetBySeasonAndUserIdAsync(incoming.SeasonId, assignee, ct)).FirstOrDefault(a => a.DayOfWeek == day.DayOfWeek);
        var exceptions=await _unitOfWork.MemberAvailabilities.GetExceptionsBySeasonAsync(incoming.SeasonId,ct) ?? [];
        available=AllocationEligibilityService.Effective(available,assignee,DateOnly.FromDateTime(day),exceptions);
        return AllocationEligibilityService.FindStart(incoming, available, assigned, _clock.GetUtcNow().UtcDateTime)
            ?? throw new ConflictException("The proposed swap does not fit declared availability.");
    }

    private async Task EnsureActiveMemberAsync(Guid houseId, Guid userId, CancellationToken cancellationToken)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member?.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("User is not an active member of this house.");
    }

    private static T Deserialize<T>(string payloadJson)
    {
        try
        {
            return JsonSerializer.Deserialize<T>(payloadJson, PayloadJsonOptions)
                ?? throw new DomainException("Proposal payload is invalid.");
        }
        catch (JsonException ex)
        {
            throw new DomainException($"Proposal payload is invalid: {ex.Message}");
        }
    }

    private static ActionProposalResponse Map(ActionProposal proposal) => new()
    {
        Id = proposal.Id,
        HouseId = proposal.HouseId,
        RoomId = proposal.RoomId,
        CreatorId = proposal.CreatorId,
        Type = proposal.Type,
        Status = proposal.Status,
        Title = proposal.Title,
        Description = proposal.Description,
        PayloadJson = proposal.PayloadJson,
        CreatedAt = proposal.CreatedAt,
        ExpiresAt = proposal.ExpiresAt,
        Confirmations = proposal.Confirmations.Select(x => new ProposalConfirmationResponse
        {
            Id = x.Id,
            TargetUserId = x.TargetUserId,
            Status = x.Status,
            Reason = x.Reason,
            RespondedAt = x.RespondedAt
        }).ToList()
    };
}
