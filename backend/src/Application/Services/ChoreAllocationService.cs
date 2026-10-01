using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Application.Services;

public class ChoreAllocationService : IChoreAllocationService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ChoreAllocationService> _logger;

    public ChoreAllocationService(IUnitOfWork unitOfWork, ILogger<ChoreAllocationService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task AllocateSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation($"Starting Workload-based allocation for season {seasonId}");

        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        if (season.AllocationMethod != AllocationMethod.AUTOMATIC)
            throw new ConflictException("Season allocation method is not set to AUTOMATIC.");

        var unassignedOccurrences = (await _unitOfWork.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, cancellationToken)).ToList();
        if (!unassignedOccurrences.Any())
        {
            _logger.LogWarning($"No unassigned occurrences found for season {seasonId}");
            return; // Nothing to allocate
        }

        var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE)
            .ToList();

        if (!members.Any())
            throw new ConflictException("No active members in the household to assign chores to.");

        var availabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(seasonId, cancellationToken);

        // Fetch constraints and preferences
        var constraints = new Dictionary<Guid, MemberConstraint>();
        var preferences = new Dictionary<Guid, List<MemberPreference>>();
        foreach (var m in members)
        {
            var c = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(m.UserId, season.HouseId, cancellationToken);
            constraints[m.UserId] = c ?? new MemberConstraint { 
                MaxChoresPerWeek = ChoreWars.Domain.Common.Constants.AIAllocationConstants.DefaultMaxChoresPerWeek, 
                MaxEffortMinutesPerDay = ChoreWars.Domain.Common.Constants.AIAllocationConstants.DefaultMaxEffortMinutesPerDay 
            };

            var p = await _unitOfWork.MemberPreferences.GetByUserIdAsync(m.UserId, cancellationToken);
            preferences[m.UserId] = p.ToList();
        }

        // Initialize state tracking
        var assignedWorkload = members.ToDictionary(m => m.UserId, m => 0); // Total minutes assigned in this session
        var choresPerWeek = members.ToDictionary(m => m.UserId, m => new Dictionary<int, int>()); // WeekOfYear -> Count
        var minutesPerDay = members.ToDictionary(m => m.UserId, m => new Dictionary<DateTime, int>()); // Date -> Minutes

        // Helper to get ISO week
        int GetIso8601WeekOfYear(DateTime time)
        {
            var cal = System.Globalization.DateTimeFormatInfo.CurrentInfo.Calendar;
            return cal.GetWeekOfYear(time, System.Globalization.CalendarWeekRule.FirstFourDayWeek, DayOfWeek.Monday);
        }

        // Sort occurrences by Difficulty (Hardest first) and then EstimatedMinutes (Longest first)
        unassignedOccurrences = unassignedOccurrences
            .OrderByDescending(o => o.Chore.Difficulty)
            .ThenByDescending(o => o.Chore.EstimatedMinutes)
            .ToList();

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            foreach (var occurrence in unassignedOccurrences)
            {
                var dueDate = occurrence.DueDate.Date;
                var dayOfWeek = dueDate.DayOfWeek;
                var weekOfYear = GetIso8601WeekOfYear(dueDate);
                var estMinutes = occurrence.Chore.EstimatedMinutes;

                // 1. Filter Valid Candidates (Hard Constraints)
                var validCandidates = members.Where(m => 
                {
                    var userId = m.UserId;
                    
                    // Availability Check
                    var availability = availabilities.FirstOrDefault(a => a.UserId == userId && a.DayOfWeek == dayOfWeek);
                    if (availability != null && !availability.IsAvailable) return false;

                    // Constraints Check
                    var c = constraints[userId];
                    
                    var currentChoresThisWeek = choresPerWeek[userId].TryGetValue(weekOfYear, out var cw) ? cw : 0;
                    if (currentChoresThisWeek >= c.MaxChoresPerWeek) return false;

                    var currentMinutesThisDay = minutesPerDay[userId].TryGetValue(dueDate, out var md) ? md : 0;
                    if (currentMinutesThisDay + estMinutes > c.MaxEffortMinutesPerDay) return false;

                    return true;
                }).ToList();

                // If no one is valid under constraints, we must fallback to all available members ignoring constraints to ensure chore gets done
                if (!validCandidates.Any())
                {
                    _logger.LogWarning($"No valid candidates for occurrence {occurrence.Id} respecting constraints. Falling back.");
                    validCandidates = members.Where(m => 
                    {
                        var availability = availabilities.FirstOrDefault(a => a.UserId == m.UserId && a.DayOfWeek == dayOfWeek);
                        return availability == null || availability.IsAvailable;
                    }).ToList();

                    if (!validCandidates.Any())
                        validCandidates = members; // Absolute fallback
                }

                // 2. Score Valid Candidates (Fairness + Preference)
                // Lower score is better (we want to pick the person with lowest workload / best preference)
                var candidateScores = validCandidates.Select(m => 
                {
                    var userId = m.UserId;
                    
                    // Workload factor
                    var workload = assignedWorkload[userId];

                    // Preference factor
                    var pref = preferences[userId].FirstOrDefault(p => p.ChoreId == occurrence.ChoreId);
                    int prefModifier = 0;
                    if (pref != null)
                    {
                        if (pref.Type == PreferenceType.LIKED) prefModifier = -30; // Reduce perceived workload
                        if (pref.Type == PreferenceType.DISLIKED) prefModifier = 30; // Increase perceived workload
                    }
                    
                    return new { Member = m, Score = workload + prefModifier };
                }).OrderBy(x => x.Score).ToList();

                var assignee = candidateScores.First().Member;

                // 3. Assign
                occurrence.AssignedUserId = assignee.UserId;
                
                // Update tracking
                assignedWorkload[assignee.UserId] += estMinutes;
                
                if (!choresPerWeek[assignee.UserId].ContainsKey(weekOfYear)) choresPerWeek[assignee.UserId][weekOfYear] = 0;
                choresPerWeek[assignee.UserId][weekOfYear]++;

                if (!minutesPerDay[assignee.UserId].ContainsKey(dueDate)) minutesPerDay[assignee.UserId][dueDate] = 0;
                minutesPerDay[assignee.UserId][dueDate] += estMinutes;

                _unitOfWork.ChoreOccurrences.Update(occurrence);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
            
            _logger.LogInformation($"Successfully allocated {unassignedOccurrences.Count} occurrences for season {seasonId}");
        }
        catch (Exception ex)
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            _logger.LogError(ex, $"Failed to allocate occurrences for season {seasonId}");
            throw;
        }
    }

    public async Task AllocateAllActiveSeasonsAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting AllocateAllActiveSeasonsAsync");
        var activeSeasons = await _unitOfWork.Seasons.GetActiveSeasonsAsync(DateTime.UtcNow, cancellationToken);
        var autoSeasons = activeSeasons.Where(s => s.AllocationMethod == AllocationMethod.AUTOMATIC).ToList();

        foreach (var season in autoSeasons)
        {
            try
            {
                await AllocateSeasonAsync(season.Id, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to allocate season {season.Id} in background worker.");
            }
        }
    }

    public async Task ManualAllocateAsync(Guid seasonId, Guid occurrenceId, Guid assigneeId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can manually allocate chores.");

        var occurrence = await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId, cancellationToken);
        if (occurrence == null)
            throw new NotFoundException(nameof(ChoreOccurrence), occurrenceId);

        // Fetch chore to verify season
        var chore = await _unitOfWork.Chores.GetByIdAsync(occurrence.ChoreId, cancellationToken);
        if (chore == null || chore.SeasonId != seasonId)
            throw new ConflictException("Occurrence does not belong to this season.");

        var assigneeMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, assigneeId, cancellationToken);
        if (assigneeMember == null || assigneeMember.Status != HouseMemberStatus.ACTIVE)
            throw new ConflictException("Assignee is not an active member of the household.");

        var availabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonAndUserIdAsync(seasonId, assigneeId, cancellationToken);
        var dayAvailability = availabilities.FirstOrDefault(a => a.DayOfWeek == occurrence.DueDate.DayOfWeek);
        if (dayAvailability != null && !dayAvailability.IsAvailable)
            throw new ConflictException("Assignee is explicitly marked as unavailable on this day.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            occurrence.AssignedUserId = assigneeId;
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
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var activeMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE)
            .ToList();

        if (activeMembers.Count < 2)
            return Enumerable.Empty<string>();

        var occurrences = (await _unitOfWork.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, cancellationToken)).ToList(); // Wait, I need ALL occurrences, not unassigned.
        // Let's create GetBySeasonIdAsync on ChoreOccurrences. For now, I can get chores then occurrences.
        var chores = await _unitOfWork.Chores.GetBySeasonIdAsync(seasonId, cancellationToken);
        var choreIds = chores.Select(c => c.Id).ToHashSet();
        
        // This could be slow if there are many chores, but it's okay for now.
        // Actually, we can just use the DB context directly or add GetBySeasonIdAsync.
        // Since I'm using _unitOfWork, let's just get occurrences by ChoreId.
        var allOccurrences = new List<ChoreOccurrence>();
        foreach(var chore in chores)
        {
            var occs = await _unitOfWork.ChoreOccurrences.GetByChoreIdAsync(chore.Id, cancellationToken);
            allOccurrences.AddRange(occs);
        }

        var assignedKarmaMap = activeMembers.ToDictionary(m => m.UserId, m => 0);
        foreach (var occ in allOccurrences.Where(o => o.AssignedUserId.HasValue))
        {
            if (assignedKarmaMap.ContainsKey(occ.AssignedUserId.Value))
            {
                assignedKarmaMap[occ.AssignedUserId.Value] += occ.SnapshotKarma;
            }
        }

        var maxKarma = assignedKarmaMap.Values.Max();
        var minKarma = assignedKarmaMap.Values.Min();

        var warnings = new List<string>();
        if (maxKarma - minKarma > 20)
        {
            var maxUser = assignedKarmaMap.First(kvp => kvp.Value == maxKarma).Key;
            var minUser = assignedKarmaMap.First(kvp => kvp.Value == minKarma).Key;
            warnings.Add($"Significant karma assignment gap: {maxKarma - minKarma} between max and min. Review schedule fairness.");
        }

        return warnings;
    }
}
