using System.Text.Json;
using System.Text.Json.Serialization;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class ActionProposalService : IActionProposalService
{
    private static readonly JsonSerializerOptions PayloadJsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly IUnitOfWork _unitOfWork;
    private readonly IActionProposalRealtimePublisher _realtimePublisher;
    private readonly INotificationService _notificationService;

    public ActionProposalService(
        IUnitOfWork unitOfWork,
        IActionProposalRealtimePublisher realtimePublisher,
        INotificationService notificationService)
    {
        _unitOfWork = unitOfWork;
        _realtimePublisher = realtimePublisher;
        _notificationService = notificationService;
    }

    public async Task<ActionProposalResponse> CreateProposalAsync(
        Guid houseId,
        CreateProposalRequest request,
        Guid creatorId,
        CancellationToken cancellationToken = default)
    {
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
            CreatedAt = DateTime.UtcNow,
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
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        var response = Map(proposal);
        await _realtimePublisher.ProposalCreatedAsync(response, cancellationToken);
        return response;
    }

    public async Task<ActionProposalResponse> RespondProposalAsync(
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

            if (proposal.Status != ProposalStatus.PENDING)
                throw new ConflictException("This proposal is no longer pending.");
            if (proposal.ExpiresAt.HasValue && proposal.ExpiresAt <= DateTime.UtcNow)
                throw new ConflictException("This proposal has expired.");

            var confirmation = proposal.Confirmations.SingleOrDefault(x => x.TargetUserId == userId)
                ?? throw new ForbiddenException("Only a target member can respond to this proposal.");
            if (confirmation.Status != ConfirmationStatus.PENDING)
                throw new ConflictException("You have already responded to this proposal.");

            confirmation.Status = request.Status;
            confirmation.Reason = string.IsNullOrWhiteSpace(request.Reason) ? null : request.Reason.Trim();
            confirmation.RespondedAt = DateTime.UtcNow;

            if (request.Status == ConfirmationStatus.REJECTED)
            {
                proposal.Status = ProposalStatus.REJECTED;
            }
            else if (proposal.Confirmations.All(x => x.Status == ConfirmationStatus.CONFIRMED))
            {
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
        await _realtimePublisher.ProposalUpdatedAsync(response, cancellationToken);

        if (proposal.Type == ProposalType.URGENT_EVENT && proposal.Status == ProposalStatus.APPROVED)
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
                    "Chiến dịch khẩn cấp đã bắt đầu!",
                    $"{proposal.Title} đã được 100% thành viên đồng ý. Đồng hồ đang đếm ngược.",
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
        var proposals = await _unitOfWork.ActionProposals.GetActiveByRoomIdAsync(roomId, DateTime.UtcNow, cancellationToken);
        return proposals.Select(Map).ToList();
    }

    private static void ValidateCreateRequest(CreateProposalRequest request, Guid creatorId)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
            throw new DomainException("Proposal title is required.");
        if (request.Title.Trim().Length > 150)
            throw new DomainException("Proposal title cannot exceed 150 characters.");
        if (request.Description?.Trim().Length > 1000)
            throw new DomainException("Proposal description cannot exceed 1000 characters.");
        if (request.TargetUserIds.Count == 0)
            throw new DomainException("At least one target member is required.");
        if (request.TargetUserIds.Contains(creatorId))
            throw new DomainException("The proposal creator cannot also be a target.");
        if (request.TargetUserIds.Count != request.TargetUserIds.Distinct().Count())
            throw new DomainException("Target members must be unique.");
        if (request.ExpiresAt.HasValue && request.ExpiresAt <= DateTime.UtcNow)
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
                break;

            case ProposalType.URGENT_EVENT:
                var urgent = Deserialize<UrgentEventPayload>(payloadJson);
                if (urgent.DeadlineMinutes is < 1 or > 1440)
                    throw new DomainException("Urgent event deadline must be between 1 and 1440 minutes.");
                if (urgent.Chores.Count == 0)
                    throw new DomainException("An urgent event must contain at least one chore.");
                if (urgent.Chores.Any(x => x.Name.Trim().Length > 100 || (x.Description?.Trim().Length ?? 0) > 500 || x.KarmaPoints < 0))
                    throw new DomainException("Urgent chore name, description, or karma value is invalid.");
                var season = await _unitOfWork.Seasons.GetByIdAsync(urgent.SeasonId, cancellationToken)
                    ?? throw new NotFoundException(nameof(ChoreSeason), urgent.SeasonId);
                if (season.HouseId != houseId)
                    throw new ForbiddenException("The selected season does not belong to this house.");
                if (season.Status != SeasonStatus.ACTIVE)
                    throw new ConflictException("Urgent events can only be created during an active season.");
                var participants = targetIds.Append(creatorId).ToHashSet();
                if (urgent.Chores.Any(x => string.IsNullOrWhiteSpace(x.Name) || !participants.Contains(x.AssignedUserId)))
                    throw new DomainException("Every urgent chore needs a name and an assignee participating in the event.");
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
            case ProposalType.CHORE_SWAP:
                var swap = Deserialize<ChoreSwapPayload>(proposal.PayloadJson);
                var source = await GetHouseOccurrenceAsync(swap.SourceOccurrenceId, proposal.HouseId, cancellationToken);
                var target = await GetHouseOccurrenceAsync(swap.TargetOccurrenceId, proposal.HouseId, cancellationToken);
                var targetUserId = proposal.Confirmations.Single().TargetUserId;
                if (source.AssignedUserId != proposal.CreatorId || target.AssignedUserId != targetUserId)
                    throw new ConflictException("Chore assignments changed after this swap was proposed.");
                if (source.Status != ChoreOccurrenceStatus.ASSIGNED || target.Status != ChoreOccurrenceStatus.ASSIGNED)
                    throw new ConflictException("Only assigned chores can be swapped.");
                (source.AssignedUserId, target.AssignedUserId) = (target.AssignedUserId, source.AssignedUserId);
                _unitOfWork.ChoreOccurrences.Update(source);
                _unitOfWork.ChoreOccurrences.Update(target);
                break;

            case ProposalType.URGENT_EVENT:
                var urgent = Deserialize<UrgentEventPayload>(proposal.PayloadJson);
                var dueDate = DateTime.UtcNow.AddMinutes(urgent.DeadlineMinutes);
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
                        Difficulty = item.Difficulty
                    };
                    await _unitOfWork.Chores.AddAsync(chore, cancellationToken);
                    await _unitOfWork.ChoreOccurrences.AddAsync(new ChoreOccurrence
                    {
                        Id = Guid.NewGuid(),
                        ChoreId = chore.Id,
                        SeasonId = urgent.SeasonId,
                        AssignedUserId = item.AssignedUserId,
                        DueDate = dueDate,
                        Status = ChoreOccurrenceStatus.ASSIGNED,
                        SnapshotKarma = item.KarmaPoints
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
