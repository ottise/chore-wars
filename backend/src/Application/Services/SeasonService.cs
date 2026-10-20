using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class SeasonService : ISeasonService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ISeasonEndService? _finalizer;
    private readonly IMapper _mapper;
    private readonly IChoreGenerationService _generationService;
    private readonly IChoreAllocationService _allocationService;

    public SeasonService(IUnitOfWork unitOfWork, IMapper mapper, IChoreGenerationService generationService, IChoreAllocationService allocationService, IHouseMutationCoordinator? mutationCoordinator = null, ISeasonEndService? finalizer = null, TimeProvider? clock = null)
    {
        _clock = clock ?? TimeProvider.System;
        _mutations = mutationCoordinator;
        _finalizer = finalizer;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _generationService = generationService;
        _allocationService = allocationService;
    }

    public async Task<SeasonResponse?> GetActiveSeasonAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("Only house members can view seasons.");

        var activeSeason = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason == null) return null;
        var response = _mapper.Map<SeasonResponse>(activeSeason);
        if (activeSeason.Status == SeasonStatus.REVIEWING) {
            var confirmations = (await _unitOfWork.SeasonConfirmations.GetBySeasonIdAsync(activeSeason.Id, cancellationToken)).Where(c => c.ScheduleRevision == activeSeason.ScheduleRevision).ToList();
            response.CurrentUserConfirmationStatus = confirmations.FirstOrDefault(c => c.UserId == userId)?.Status;
            response.ConfirmedCount = confirmations.Count(c => c.Status == ConfirmationStatus.CONFIRMED);
            response.RequiredConfirmationCount = confirmations.Count;
        }
        return response;
    }

    public async Task<IEnumerable<SeasonResponse>> GetSeasonsByHouseAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("Only house members can view seasons.");

        var seasons = await _unitOfWork.Seasons.GetByHouseIdAsync(houseId, cancellationToken);
        return _mapper.Map<IEnumerable<SeasonResponse>>(seasons);
    }

    public async Task<SeasonResponse> CreateSeasonAsync(Guid houseId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await CreateSeasonCoreAsync(houseId, request, userId, cancellationToken);

        return await _mutations.RunAsync(houseId, () => CreateSeasonCoreAsync(houseId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task<SeasonResponse> CreateSeasonCoreAsync(Guid houseId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var houseContext = await _unitOfWork.Houses.GetByIdAsync(houseId,cancellationToken) ?? throw new NotFoundException("Household not found.");
        if (houseContext.IsArchived) throw new ConflictException("Archived households are read-only.");
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can create a season.");

        var activeSeason = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason != null)
            throw new ConflictException("There is already an unfinished season in this house.");

        if (request.EndDate <= request.StartDate)
            throw new DomainException("StartDate must be before EndDate.");

        if (request.EndDate > request.StartDate.AddMonths(SeasonConstants.MaxDurationMonths) &&
            (request.EndDate - request.StartDate).TotalDays > SeasonConstants.MaxDurationDays)
        {
            throw new DomainException("Season duration cannot exceed 1 month.");
        }

        var season = new ChoreSeason
        {
            Id = Guid.NewGuid(),
            HouseId = houseId,
            Name = request.Name,
            StartDate = ScheduleTime.Utc(DateOnly.FromDateTime(ScheduleTime.Local(request.StartDate.ToUniversalTime())),0),
            EndDate = ScheduleTime.Utc(DateOnly.FromDateTime(ScheduleTime.Local(request.EndDate.ToUniversalTime())),1440).AddTicks(-1),
            Status = SeasonStatus.DRAFT,
            AllocationMethod = request.AllocationMethod
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Seasons.AddAsync(season, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<SeasonResponse>(season);
    }

    public Task StartSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
        => ConfirmSeasonAsync(seasonId, userId, cancellationToken);

    public async Task EndSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can end a season.");

        if (season.Status != SeasonStatus.ACTIVE)
            throw new ConflictException("Season must be in ACTIVE state to end.");

        if (_clock.GetUtcNow().UtcDateTime <= season.EndDate)
            throw new ConflictException("The season cannot end before its scheduled cutoff.");
        if (_finalizer == null) throw new ConflictException("Season finalizer is unavailable.");
        await _finalizer.FinalizeSeasonAsync(seasonId,cancellationToken);
    }

    public async Task<MemberAvailabilityRequest> GetAvailabilityAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("You must be an active member of the house.");

        var existingAvailabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);

        var request = new MemberAvailabilityRequest();
        foreach (var existing in existingAvailabilities)
        {
            request.Availabilities[(int)existing.DayOfWeek] = existing.IsAvailable;
            request.Slots[(int)existing.DayOfWeek] = existing.Slots.Select(x => new AvailabilitySlotRequest { StartMinute = x.StartMinute, EndMinute = x.EndMinute }).ToList();
        }

        return request;
    }

    public async Task SetAvailabilityAsync(Guid seasonId, MemberAvailabilityRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await SetAvailabilityCoreAsync(seasonId, request, userId, cancellationToken); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => SetAvailabilityCoreAsync(seasonId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task SetAvailabilityCoreAsync(Guid seasonId, MemberAvailabilityRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("You must be an active member of the house.");

        if (season.Status != SeasonStatus.DRAFT) throw new ConflictException("Availability is locked outside draft.");
        if (request.Availabilities.Keys.Concat(request.Slots.Keys).Any(day => day < 0 || day > 6))
            throw new DomainException("Weekday must be between 0 and 6.");
        foreach (var slots in request.Slots.Values) {
            var ordered = slots.OrderBy(x => x.StartMinute).ToList();
            for (var i = 0; i < ordered.Count; i++) {
                var slot = ordered[i];
                if (slot.StartMinute < 0 || slot.EndMinute > 1440 || slot.EndMinute <= slot.StartMinute || (i > 0 && ordered[i-1].EndMinute > slot.StartMinute))
                    throw new DomainException("Availability intervals must be valid and must not overlap.");
            }
        }
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            if (season.AllocationMethod == AllocationMethod.AUTOMATIC && await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(seasonId,cancellationToken))
                await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(seasonId,cancellationToken);
            season.ScheduleRevision++; _unitOfWork.Seasons.Update(season);
            var existingAvailabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);
            foreach (var existing in existingAvailabilities)
            {
                _unitOfWork.MemberAvailabilities.Delete(existing);
            }

            foreach (var day in request.Availabilities.Keys.Concat(request.Slots.Keys).Distinct())
            {
                var availability = new MemberAvailability
                {
                    Id = Guid.NewGuid(),
                    SeasonId = seasonId,
                    UserId = userId,
                    DayOfWeek = (DayOfWeek)day,
                    IsAvailable = request.Slots.TryGetValue(day, out var windows) ? windows.Count > 0 : request.Availabilities.GetValueOrDefault(day),
                    Slots = request.Slots.TryGetValue(day, out var intervals)
                        ? intervals.Select(x => new MemberAvailabilitySlot { Id = Guid.NewGuid(), StartMinute = x.StartMinute, EndMinute = x.EndMinute }).ToList()
                        : new List<MemberAvailabilitySlot>()
                };
                await _unitOfWork.MemberAvailabilities.AddAsync(availability, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<SeasonRankingResponse>> GetRankingsAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var rankings = await _unitOfWork.SeasonRankings.GetBySeasonIdAsync(seasonId, cancellationToken);
        var snapshot = rankings.ToList();
        if (snapshot.Count > 0)
            return _mapper.Map<IEnumerable<SeasonRankingResponse>>(snapshot);

        var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken);
        var transactions = await _unitOfWork.KarmaTransactions.GetBySeasonIdAsync(seasonId, cancellationToken);
        var liveRanking = members
            .Select(houseMember =>
            {
                var memberTransactions = transactions
                    .Where(item => item.UserId == houseMember.UserId)
                    .ToList();
                return new
                {
                    houseMember.UserId,
                    houseMember.JoinedAt,
                    houseMember.User.DisplayName,
                    TotalKarma = memberTransactions.Sum(item => item.Amount),
                    Completed = memberTransactions.Count(item =>
                        item.Type == KarmaTransactionType.CHORE_COMPLETED),
                    Bonus = memberTransactions.Where(item =>
                        item.Type is KarmaTransactionType.BONUS or KarmaTransactionType.BOUNTY_REWARD).Sum(item => item.Amount)
                };
            })
            .OrderByDescending(item => item.TotalKarma)
            .ThenByDescending(item => item.Completed)
            .ThenByDescending(item => item.Bonus)
            .ThenBy(item => item.JoinedAt)
            .ThenBy(item => item.UserId)
            .ToList();

        return liveRanking.Select((item, index) => new SeasonRankingResponse
        {
            UserId = item.UserId,
            DisplayName = item.DisplayName,
            TotalKarma = item.TotalKarma,
            Rank = index + 1,
            ChoresCompleted = item.Completed
        });
    }

    public async Task<SeasonResponse> CloneSeasonAsync(Guid seasonId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await CloneSeasonCoreAsync(seasonId, request, userId, cancellationToken);
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        return await _mutations.RunAsync(context.HouseId, () => CloneSeasonCoreAsync(seasonId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task<SeasonResponse> CloneSeasonCoreAsync(Guid seasonId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var originalSeason = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (originalSeason == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(originalSeason.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can clone a season.");

        var activeSeason = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(originalSeason.HouseId, cancellationToken);
        if (activeSeason != null)
            throw new ConflictException("There is already an active season in this house.");

        if (request.EndDate <= request.StartDate)
            throw new DomainException("StartDate must be before EndDate.");

        if (request.EndDate > request.StartDate.AddMonths(SeasonConstants.MaxDurationMonths) &&
            (request.EndDate - request.StartDate).TotalDays > SeasonConstants.MaxDurationDays)
        {
            throw new DomainException("Season duration cannot exceed 1 month.");
        }

        var newSeason = new ChoreSeason
        {
            Id = Guid.NewGuid(),
            HouseId = originalSeason.HouseId,
            Name = request.Name,
            StartDate = ScheduleTime.Utc(DateOnly.FromDateTime(ScheduleTime.Local(request.StartDate.ToUniversalTime())),0),
            EndDate = ScheduleTime.Utc(DateOnly.FromDateTime(ScheduleTime.Local(request.EndDate.ToUniversalTime())),1440).AddTicks(-1),
            Status = SeasonStatus.DRAFT,
            AllocationMethod = request.AllocationMethod
        };

        var originalChores = await _unitOfWork.Chores.GetBySeasonIdAsync(seasonId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Seasons.AddAsync(newSeason, cancellationToken);

            foreach (var oldChore in originalChores)
            {
                var newChore = new Chore
                {
                    Id = Guid.NewGuid(),
                    HouseId = newSeason.HouseId,
                    SeasonId = newSeason.Id,
                    Name = oldChore.Name,
                    Description = oldChore.Description,
                    KarmaPoints = oldChore.KarmaPoints,
                    Type = oldChore.Type,
                    FrequencyType = oldChore.FrequencyType,
                    FrequencyValue = oldChore.FrequencyValue,
                    Difficulty = oldChore.Difficulty, EstimatedMinutes = oldChore.EstimatedMinutes,
                    SourceTemplateId = oldChore.SourceTemplateId ?? oldChore.Id, DeadlineMinutes = oldChore.DeadlineMinutes,
                    RecurrenceAnchor = oldChore.RecurrenceAnchor, CustomDates = oldChore.CustomDates.ToList()
                };

                foreach (var oldDay in oldChore.FrequencyDays)
                {
                    newChore.FrequencyDays.Add(new ChoreFrequencyDay
                    {
                        Id = Guid.NewGuid(),
                        ChoreId = newChore.Id,
                        DayOfWeek = oldDay.DayOfWeek
                    });
                }

                await _unitOfWork.Chores.AddAsync(newChore, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<SeasonResponse>(newSeason);
    }

    public async Task GenerateScheduleAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await GenerateScheduleCoreAsync(seasonId, userId, cancellationToken); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => GenerateScheduleCoreAsync(seasonId, userId, cancellationToken), cancellationToken);
    }

    private async Task GenerateScheduleCoreAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can generate a schedule.");

        if (season.Status != SeasonStatus.DRAFT)
            throw new ConflictException("Season must be in DRAFT state to generate schedule.");

        if (await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(seasonId, cancellationToken))
            await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(seasonId, cancellationToken);
        await _generationService.GenerateOccurrencesAsync(seasonId, userId, cancellationToken);
        if (season.AllocationMethod == AllocationMethod.AUTOMATIC)
            await _allocationService.AllocateSeasonAsync(seasonId, cancellationToken);
        season.ScheduleRevision++;
        _unitOfWork.Seasons.Update(season);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task SubmitReviewAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await SubmitReviewCoreAsync(seasonId, userId, cancellationToken); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => SubmitReviewCoreAsync(seasonId, userId, cancellationToken), cancellationToken);
    }

    private async Task SubmitReviewCoreAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken)
            ?? throw new NotFoundException(nameof(ChoreSeason), seasonId);
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member?.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER) throw new ForbiddenException();
        if (season.Status != SeasonStatus.DRAFT) throw new ConflictException("Only draft schedules can be submitted.");
        var requiredMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken)).Where(m => m.Status == HouseMemberStatus.ACTIVE).ToList();
        if (requiredMembers.Count < 3) throw new ConflictException("At least three active members are required for review.");
        var mandatory = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(seasonId, cancellationToken)).Where(o => o.Chore.Type == ChoreType.NORMAL).ToList();
        if (mandatory.Count == 0 || mandatory.Any(o => o.AssignedUserId == null || !requiredMembers.Any(m => m.UserId == o.AssignedUserId)))
            throw new ConflictException("Assign all mandatory chores to active members before review.");
        await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(seasonId, cancellationToken);
        // 3. Update Season status to REVIEWING
        season.Status = SeasonStatus.REVIEWING;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Seasons.Update(season);

            // 4. Create SeasonConfirmation records for all active members
            var activeMembers = await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken);
            foreach (var activeMember in activeMembers.Where(m => m.Status == HouseMemberStatus.ACTIVE))
            {
                var confirmation = new SeasonConfirmation
                {
                    Id = Guid.NewGuid(),
                    SeasonId = seasonId,
                    ScheduleRevision = season.ScheduleRevision,
                    UserId = activeMember.UserId,
                    Status = ConfirmationStatus.PENDING,
                    CreatedAt = _clock.GetUtcNow().UtcDateTime
                };
                await _unitOfWork.SeasonConfirmations.AddAsync(confirmation, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task ConfirmSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default, int? expectedRevision = null)
    {
        if (_mutations == null) { await ConfirmSeasonCoreAsync(seasonId, userId, cancellationToken, expectedRevision); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => ConfirmSeasonCoreAsync(seasonId, userId, cancellationToken, expectedRevision), cancellationToken);
    }

    private async Task ConfirmSeasonCoreAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default, int? expectedRevision = null)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        if (expectedRevision != season.ScheduleRevision) throw new ConflictException("Review the current schedule revision before confirming.");
        if (season.Status != SeasonStatus.REVIEWING)
            throw new ConflictException("Season must be in REVIEWING state to confirm.");

        var confirmation = await _unitOfWork.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);
        if (confirmation == null)
            throw new ForbiddenException("You are not eligible to confirm this season.");

        var activeMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken)).Where(m => m.Status == HouseMemberStatus.ACTIVE).ToList();
        var confirmations = (await _unitOfWork.SeasonConfirmations.GetBySeasonIdAsync(seasonId, cancellationToken)).ToList();
        if (!activeMembers.Any(m => m.UserId == userId)) throw new ForbiddenException();
        if (activeMembers.Count < 3 || confirmations.Count != activeMembers.Count || activeMembers.Any(m => !confirmations.Any(c => c.UserId == m.UserId && c.ScheduleRevision == season.ScheduleRevision)))
            throw new ConflictException("Membership or schedule changed. Submit the draft for review again.");
        if (confirmation.ScheduleRevision != season.ScheduleRevision) throw new ConflictException("Schedule revision changed.");
        if (confirmation.Status == ConfirmationStatus.CONFIRMED) return;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            confirmation.Status = ConfirmationStatus.CONFIRMED;
            _unitOfWork.SeasonConfirmations.Update(confirmation);

            // Activation requires every member from this exact revision.
            if (confirmations.All(c => c.UserId == userId || c.Status == ConfirmationStatus.CONFIRMED))
                season.Status = SeasonStatus.ACTIVE;
            _unitOfWork.Seasons.Update(season);

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task RejectSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default, string? reason = null)
    {
        if (_mutations == null) { await RejectSeasonCoreAsync(seasonId, userId, cancellationToken, reason); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => RejectSeasonCoreAsync(seasonId, userId, cancellationToken, reason), cancellationToken);
    }

    private async Task RejectSeasonCoreAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default, string? reason = null)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        if (season.Status != SeasonStatus.REVIEWING)
            throw new ConflictException("Season must be in REVIEWING state to reject.");

        var confirmation = await _unitOfWork.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);
        if (confirmation == null)
            throw new ForbiddenException("You are not eligible to reject this season.");

        var rejectingMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId,userId,cancellationToken);
        if (rejectingMember?.Status != HouseMemberStatus.ACTIVE) throw new ForbiddenException();
        if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length > 1000) throw new DomainException("Provide a rejection reason within 1000 characters.");
        season.LastRejectionReason = reason.Trim(); season.LastRejectedByUserId = userId; season.ScheduleRevision++;
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            season.Status = SeasonStatus.DRAFT;
            _unitOfWork.Seasons.Update(season);

            await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(seasonId, cancellationToken);
            await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(seasonId, cancellationToken);

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<ChoreWars.Application.DTOs.Chore.ChoreOccurrenceResponse>> GetOccurrencesAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("Only house members can view occurrences.");

        var occurrences = await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(seasonId, cancellationToken);
        return _mapper.Map<IEnumerable<ChoreWars.Application.DTOs.Chore.ChoreOccurrenceResponse>>(occurrences);
    }
}

