using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Application.Services;

public class ChoreAllocationService : IChoreAllocationService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ChoreAllocationService> _logger;

    public ChoreAllocationService(IUnitOfWork unitOfWork, ILogger<ChoreAllocationService> logger, IHouseMutationCoordinator? mutationCoordinator = null, TimeProvider? clock = null)
    {
        _clock = clock ?? TimeProvider.System;
        _mutations = mutationCoordinator;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task AllocateSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await AllocateSeasonCoreAsync(seasonId, cancellationToken); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => AllocateSeasonCoreAsync(seasonId, cancellationToken), cancellationToken);
    }

    private async Task AllocateSeasonCoreAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException(nameof(ChoreSeason), seasonId);
        if (season.Status != SeasonStatus.DRAFT || season.AllocationMethod != AllocationMethod.AUTOMATIC)
            throw new ConflictException("Automatic allocation only applies to automatic draft seasons.");
        var occurrences = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(seasonId, cancellationToken)).Where(o => o.Chore.Type == ChoreType.NORMAL).ToList();
        var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken)).Where(m => m.Status == HouseMemberStatus.ACTIVE).ToList();
        var availability = (await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(seasonId, cancellationToken)).ToList();
        var dateExceptions = await _unitOfWork.MemberAvailabilities.GetExceptionsBySeasonAsync(seasonId, cancellationToken) ?? [];
        var constraints = new Dictionary<Guid, MemberConstraint>();
        var preferences = new Dictionary<Guid, List<MemberPreference>>();
        foreach (var member in members)
        {
            constraints[member.UserId] = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(member.UserId, season.HouseId, cancellationToken)
                ?? new MemberConstraint { MaxChoresPerWeek = AIAllocationConstants.DefaultMaxChoresPerWeek, MaxEffortMinutesPerDay = AIAllocationConstants.DefaultMaxEffortMinutesPerDay };
            preferences[member.UserId] = (await _unitOfWork.MemberPreferences.GetByUserIdAsync(member.UserId, cancellationToken)).ToList();
        }
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            foreach (var occurrence in occurrences.Where(o => !o.AssignedUserId.HasValue).OrderBy(o => o.DueDate).ThenByDescending(o => o.SnapshotKarma).ThenBy(o => o.Id))
            {
                var date = ScheduleTime.Local(occurrence.DueDate).Date;
                var week = System.Globalization.ISOWeek.GetWeekOfYear(date);
                var year = System.Globalization.ISOWeek.GetYear(date);
                var candidates = new List<(Guid UserId, int Karma, int Rotation, int Preference, int Count, DateTime Start)>();
                foreach (var member in members)
                {
                    var assigned = occurrences.Where(o => o.AssignedUserId == member.UserId).ToList();
                    var limit = constraints[member.UserId];
                    if (assigned.Count(o => { var d = ScheduleTime.Local(o.DueDate); return System.Globalization.ISOWeek.GetYear(d) == year && System.Globalization.ISOWeek.GetWeekOfYear(d) == week; }) >= limit.MaxChoresPerWeek) continue;
                    if (assigned.Where(o => ScheduleTime.Local(o.DueDate).Date == date).Sum(AllocationEligibilityService.Minutes) + AllocationEligibilityService.Minutes(occurrence) > limit.MaxEffortMinutesPerDay) continue;
                    var effective = AllocationEligibilityService.Effective(availability.FirstOrDefault(a => a.UserId == member.UserId && a.DayOfWeek == date.DayOfWeek), member.UserId, DateOnly.FromDateTime(date), dateExceptions);
                    var start = AllocationEligibilityService.FindStart(occurrence, effective, assigned);
                    if (start == null) continue;
                    var pref = preferences[member.UserId].FirstOrDefault(p => p.ChoreId == occurrence.ChoreId)?.Type;
                    var previousMonday = date.AddDays(-((int)date.DayOfWeek + 6) % 7 - 7);
                    var rotation = assigned.Any(o => o.ChoreId == occurrence.ChoreId && ScheduleTime.Local(o.DueDate).Date >= previousMonday && ScheduleTime.Local(o.DueDate).Date < previousMonday.AddDays(7)) ? 1 : 0;
                    candidates.Add((member.UserId, assigned.Sum(o => o.SnapshotKarma), rotation, pref == PreferenceType.PREFERRED ? -1 : pref == PreferenceType.DISLIKED ? 1 : 0, assigned.Count, start.Value));
                }
                if (candidates.Count == 0) continue; // Keep unassigned; never override a hard constraint.
                var selected = candidates.OrderBy(x => x.Karma).ThenBy(x => x.Rotation).ThenBy(x => x.Preference).ThenBy(x => x.Count).ThenBy(x => x.UserId).First();
                occurrence.AssignedUserId = selected.UserId;
                occurrence.PlannedStartAt = selected.Start;
                _unitOfWork.ChoreOccurrences.Update(occurrence);
            }
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch { await _unitOfWork.RollbackTransactionAsync(cancellationToken); throw; }
    }

    public Task AllocateAllActiveSeasonsAsync(CancellationToken cancellationToken = default)
        => Task.CompletedTask; // Approved schedules are immutable; allocate only explicitly in draft.

    public async Task ManualAllocateAsync(Guid seasonId, Guid occurrenceId, Guid assigneeId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await ManualAllocateCoreAsync(seasonId, occurrenceId, assigneeId, userId, cancellationToken); return; }
        var context = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken) ?? throw new NotFoundException("Season not found.");
        await _mutations.RunAsync(context.HouseId, () => ManualAllocateCoreAsync(seasonId, occurrenceId, assigneeId, userId, cancellationToken), cancellationToken);
    }

    private async Task ManualAllocateCoreAsync(Guid seasonId, Guid occurrenceId, Guid assigneeId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only active house owners can manually allocate chores.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);

        if (season.Status != SeasonStatus.DRAFT && (season.Status != SeasonStatus.ACTIVE || occurrence.AssignedUserId.HasValue || occurrence.DueDate <= _clock.GetUtcNow().UtcDateTime)) throw new ConflictException("Only draft assignments or future unassigned active chores can be allocated.");
        // Fetch chore to verify season
        var chore = await _unitOfWork.Chores.GetByIdAsync(occurrence.ChoreId, cancellationToken);
        if (chore == null || occurrence.SeasonId != seasonId || chore.HouseId != season.HouseId)
            throw new ConflictException("Occurrence does not belong to this season.");
        if (chore.Type != ChoreType.NORMAL)
            throw new ConflictException("Bonus chores must be claimed after the season starts.");

        var assigneeMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, assigneeId, cancellationToken);
        if (assigneeMember == null || assigneeMember.Status != HouseMemberStatus.ACTIVE)
            throw new ConflictException("Assignee is not an active member of the household.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            DateTime? start = null;
            if (season.Status == SeasonStatus.ACTIVE)
            {
                var all = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(season.Id, cancellationToken)).ToList();
                var weekly = (await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(season.Id, cancellationToken)).ToList();
                var exceptions = (await _unitOfWork.MemberAvailabilities.GetExceptionsBySeasonAsync(season.Id, cancellationToken)).ToList();
                start = await ChoreSchedulingService.AvailableStartAsync(_unitOfWork, season.HouseId, occurrence, assigneeId, all, weekly, exceptions, _clock.GetUtcNow().UtcDateTime, cancellationToken);
                if (!start.HasValue) throw new ConflictException("No valid time slot is available for this member. Review availability and workload limits.");
            }
            occurrence.AssignedUserId = assigneeId;
            occurrence.PlannedStartAt = start;
            if (season.Status == SeasonStatus.ACTIVE) await ChoreResponsibilityService.EnsureAsync(_unitOfWork, occurrence, _clock.GetUtcNow().UtcDateTime, cancellationToken);
            season.ScheduleRevision++; _unitOfWork.Seasons.Update(season);
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

    public async Task<IEnumerable<string>> GetFairnessWarningsAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        var summary = await GetWorkloadSummaryAsync(seasonId, cancellationToken);
        return summary.Warnings;
    }

    public async Task<WorkloadSummaryResponse> GetWorkloadSummaryAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var activeMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE)
            .ToList();

        var allOccurrences = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(seasonId, cancellationToken))
            .Where(o => o.Chore.Type == ChoreType.NORMAL)
            .ToList();

        var response = new WorkloadSummaryResponse { UnassignedCount = allOccurrences.Count(o => !o.AssignedUserId.HasValue) };
        if (response.UnassignedCount > 0) response.Warnings.Add($"{response.UnassignedCount} mandatory chores remain unassigned.");
        var availabilities = (await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(seasonId, cancellationToken)).ToList();

        foreach (var member in activeMembers)
        {
            var memberOccs = allOccurrences
                .Where(o => o.AssignedUserId == member.UserId)
                .ToList();

            if (season.AllocationMethod == AllocationMethod.MANUAL)
            {
                foreach (var day in memberOccs.GroupBy(o => ScheduleTime.Local(o.DueDate).Date))
                {
                    var available = availabilities.FirstOrDefault(a => a.UserId == member.UserId && a.DayOfWeek == day.Key.DayOfWeek);
                    var freeMinutes = available?.IsAvailable == true ? (available.Slots.Count == 0 ? 1440 : available.Slots.Sum(s => s.EndMinute - s.StartMinute)) : 0;
                    if (day.Sum(AllocationEligibilityService.Minutes) > freeMinutes || day.Any(o => AllocationEligibilityService.FindStart(o, available, Array.Empty<ChoreOccurrence>()) == null))
                        response.Warnings.Add($"{member.User.DisplayName}: assignments on {day.Key:yyyy-MM-dd} exceed declared availability. Manual allocation requires household review.");
                }
            }

            response.Members.Add(new MemberWorkload
            {
                UserId = member.UserId,
                DisplayName = member.User.DisplayName,
                TotalChores = memberOccs.Count,
                TotalEstimatedMinutes = memberOccs.Sum(AllocationEligibilityService.Minutes),
                TotalAssignedKarma = memberOccs.Sum(o => o.SnapshotKarma),
                TotalKarma = memberOccs.Sum(o => o.SnapshotKarma),
                EasyCount = memberOccs.Count(o => o.Chore.Difficulty == ChoreEffort.EASY),
                MediumCount = memberOccs.Count(o => o.Chore.Difficulty == ChoreEffort.MEDIUM),
                HardCount = memberOccs.Count(o => o.Chore.Difficulty == ChoreEffort.HARD),
            });
        }

        if (response.Members.Count >= 2)
        {
            var karmaGap = response.Members.Max(m => m.TotalAssignedKarma) - response.Members.Min(m => m.TotalAssignedKarma);
            var averageKarma = response.Members.Average(m => m.TotalAssignedKarma);
            response.KarmaVariancePercentage = averageKarma > 0 ? Math.Round(karmaGap / averageKarma * 100, 2) : 0;
            if (response.KarmaVariancePercentage > 20)
                response.Warnings.Add($"Karma gap: variance of {response.KarmaVariancePercentage:F1}% exceeds 20% fairness threshold. Consider rebalancing.");
            if (karmaGap > 0) response.Warnings.Add($"Assigned Karma gap: {karmaGap}. Review the distribution before approval.");
            var maxMinutes = response.Members.Max(m => m.TotalEstimatedMinutes);
            var minMinutes = response.Members.Min(m => m.TotalEstimatedMinutes);
            var minuteGap = maxMinutes - minMinutes;

            if (minuteGap > AIAllocationConstants.FairnessThresholdMinutes)
            {
                response.Warnings.Add(
                    $"Workload gap: {minuteGap} minutes between highest and lowest. Consider reviewing.");
            }

            var maxChores = response.Members.Max(m => m.TotalChores);
            var minChores = response.Members.Min(m => m.TotalChores);
            var choreGap = maxChores - minChores;

            if (choreGap > AIAllocationConstants.FairnessThresholdChores)
            {
                response.Warnings.Add(
                    $"Chore count gap: {choreGap} chores. Consider rebalancing.");
            }
        }

        return response;
    }
}
