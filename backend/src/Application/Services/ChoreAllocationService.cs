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
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<Guid, List<string>> _seasonWarnings = new();
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ChoreAllocationService> _logger;

    public List<string> Warnings { get; } = new();

    public ChoreAllocationService(IUnitOfWork unitOfWork, ILogger<ChoreAllocationService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    private static int GetIso8601WeekOfYear(DateTime time)
    {
        var cal = System.Globalization.DateTimeFormatInfo.CurrentInfo.Calendar;
        return cal.GetWeekOfYear(time, System.Globalization.CalendarWeekRule.FirstFourDayWeek, DayOfWeek.Monday);
    }

    private void AddWarning(Guid seasonId, string warning)
    {
        _seasonWarnings.AddOrUpdate(
            seasonId,
            _ => new List<string> { warning },
            (_, list) => { lock (list) { list.Add(warning); } return list; }
        );
        lock (Warnings)
        {
            Warnings.Add(warning);
        }
    }

    public async Task AllocateSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
<<<<<<< Updated upstream
        _logger.LogInformation($"Starting allocation for season {seasonId}");
=======
        _logger.LogInformation($"Starting Karma-centric allocation for season {seasonId}");
>>>>>>> Stashed changes

        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

<<<<<<< Updated upstream
        if (season.AllocationMethod != AllocationMethod.AUTOMATIC)
            throw new ConflictException("Season allocation method is not set to AUTOMATIC.");

=======
>>>>>>> Stashed changes
        var unassignedOccurrences = (await _unitOfWork.ChoreOccurrences.GetUnassignedBySeasonIdAsync(seasonId, cancellationToken)).ToList();
        if (!unassignedOccurrences.Any())
        {
            _logger.LogWarning($"No unassigned occurrences found for season {seasonId}");
            return;
        }

        var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE)
            .ToList();

        if (!members.Any())
            throw new ConflictException("No active members in the household to assign chores to.");

        var availabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonIdAsync(seasonId, cancellationToken); // Wait, we don't have GetBySeasonIdAsync yet, let's just get it per member or use a new method. I'll need to create GetBySeasonIdAsync.

<<<<<<< Updated upstream
        // Initialize assigned karma tracker for this allocation session to balance workload
        var assignedKarma = members.ToDictionary(m => m.UserId, m => 0);
=======
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
        var memberKarmaSum = members.ToDictionary(m => m.UserId, m => 0); // Karma-centric balance tracker
        var weeklyChoreAssignments = new HashSet<(Guid UserId, Guid ChoreId, int WeekOfYear)>(); // Rotation tracker

        // Pre-populate with existing assigned occurrences in the season
        var existingAssignedOccurrences = (await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(seasonId, cancellationToken))
            .Where(o => o.AssignedUserId.HasValue)
            .ToList();

        foreach (var existing in existingAssignedOccurrences)
        {
            var uId = existing.AssignedUserId!.Value;
            var w = GetIso8601WeekOfYear(existing.DueDate.Date);
            var d = existing.DueDate.Date;
            var k = existing.Chore?.KarmaPoints ?? (existing.SnapshotKarma > 0 ? existing.SnapshotKarma : 0);
            var mins = existing.Chore?.EstimatedMinutes ?? 30;

            if (memberKarmaSum.ContainsKey(uId)) memberKarmaSum[uId] += k;
            if (assignedWorkload.ContainsKey(uId)) assignedWorkload[uId] += mins;

            weeklyChoreAssignments.Add((uId, existing.ChoreId, w));

            if (choresPerWeek.ContainsKey(uId))
            {
                if (!choresPerWeek[uId].ContainsKey(w)) choresPerWeek[uId][w] = 0;
                choresPerWeek[uId][w]++;
            }

            if (minutesPerDay.ContainsKey(uId))
            {
                if (!minutesPerDay[uId].ContainsKey(d)) minutesPerDay[uId][d] = 0;
                minutesPerDay[uId][d] += mins;
            }
        }

        // Sort occurrences by KarmaPoints descending, then Difficulty descending, then chronologically
        unassignedOccurrences = unassignedOccurrences
            .OrderByDescending(o => o.Chore?.KarmaPoints ?? 0)
            .ThenByDescending(o => o.Chore?.Difficulty ?? ChoreEffort.EASY)
            .ThenBy(o => o.DueDate)
            .ToList();
>>>>>>> Stashed changes

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            foreach (var occurrence in unassignedOccurrences)
            {
<<<<<<< Updated upstream
                var dayOfWeek = occurrence.DueDate.DayOfWeek;

                // Find eligible members (available on this day)
                // If a user has explicitly set IsAvailable = false for this DayOfWeek, they are not eligible.
                // Otherwise, they are eligible.
                var eligibleMembers = members.Where(m => 
                {
                    var availability = availabilities.FirstOrDefault(a => a.UserId == m.UserId && a.DayOfWeek == dayOfWeek);
                    return availability == null || availability.IsAvailable;
                }).ToList();

                // If no one is available, fallback to all members
                if (!eligibleMembers.Any())
                    eligibleMembers = members;
=======
                if (occurrence.Chore?.Type == ChoreType.BONUS)
                {
                    continue; // Bonus chores remain unassigned for members to claim
                }

                var dueDate = occurrence.DueDate.Date;
                var dayOfWeek = dueDate.DayOfWeek;
                var weekOfYear = GetIso8601WeekOfYear(dueDate);
                var estMinutes = occurrence.Chore?.EstimatedMinutes ?? 30;
                var choreKarma = occurrence.Chore?.KarmaPoints ?? 0;

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

                // If no one is valid under constraints, fallback and record warning
                bool constraintConflict = false;
                if (!validCandidates.Any())
                {
                    constraintConflict = true;
                    _logger.LogWarning($"No valid candidates for occurrence {occurrence.Id} respecting constraints. Falling back.");
                    
                    validCandidates = members.Where(m => 
                    {
                        var availability = availabilities.FirstOrDefault(a => a.UserId == m.UserId && a.DayOfWeek == dayOfWeek);
                        return availability == null || availability.IsAvailable;
                    }).ToList();
>>>>>>> Stashed changes

                // Sort by least assigned karma in this session, then by least overall KarmaBalance to distribute fairly
                var assignee = eligibleMembers
                    .OrderBy(m => assignedKarma[m.UserId])
                    .ThenBy(m => m.KarmaBalance)
                    .First();

<<<<<<< Updated upstream
                occurrence.AssignedUserId = assignee.UserId;
                assignedKarma[assignee.UserId] += occurrence.SnapshotKarma;
=======
                // 2. Score Candidates (Karma-centric + Chore Rotation Penalty + Preference)
                var candidateScores = validCandidates.Select(m => 
                {
                    var userId = m.UserId;
                    var karma = memberKarmaSum[userId];

                    // Chore Rotation Penalty: Phạt +50 điểm cost nếu đã làm việc X ở tuần liền trước
                    int rotationPenalty = 0;
                    if (weeklyChoreAssignments.Contains((userId, occurrence.ChoreId, weekOfYear - 1)))
                    {
                        rotationPenalty = 50;
                    }

                    // Preference factor
                    var pref = preferences[userId].FirstOrDefault(p => p.ChoreId == occurrence.ChoreId);
                    int prefModifier = 0;
                    if (pref != null)
                    {
                        if (pref.Type == PreferenceType.PREFERRED) prefModifier = -15;
                        if (pref.Type == PreferenceType.DISLIKED) prefModifier = 15;
                    }
                    
                    var score = karma + rotationPenalty + prefModifier;
                    return new { Member = m, Score = score, Karma = karma, Workload = assignedWorkload[userId] };
                })
                .OrderBy(x => x.Score)
                .ThenBy(x => x.Karma)
                .ThenBy(x => x.Workload)
                .ToList();

                var assignee = candidateScores.First().Member;

                if (constraintConflict)
                {
                    var choreName = occurrence.Chore?.Name ?? occurrence.ChoreId.ToString();
                    var memberName = assignee.User?.DisplayName ?? assignee.UserId.ToString();
                    AddWarning(seasonId, $"Constraint conflict for chore '{choreName}' on {dueDate:yyyy-MM-dd}: forced assignment to {memberName}.");
                }

                // 3. Assign
                occurrence.AssignedUserId = assignee.UserId;
                occurrence.SnapshotKarma = choreKarma;
                
                // Update tracking
                memberKarmaSum[assignee.UserId] += choreKarma;
                assignedWorkload[assignee.UserId] += estMinutes;
                weeklyChoreAssignments.Add((assignee.UserId, occurrence.ChoreId, weekOfYear));
                
                if (!choresPerWeek[assignee.UserId].ContainsKey(weekOfYear)) choresPerWeek[assignee.UserId][weekOfYear] = 0;
                choresPerWeek[assignee.UserId][weekOfYear]++;

                if (!minutesPerDay[assignee.UserId].ContainsKey(dueDate)) minutesPerDay[assignee.UserId][dueDate] = 0;
                minutesPerDay[assignee.UserId][dueDate] += estMinutes;
>>>>>>> Stashed changes

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
            occurrence.SnapshotKarma = chore.KarmaPoints;
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
<<<<<<< Updated upstream
            var occs = await _unitOfWork.ChoreOccurrences.GetByChoreIdAsync(chore.Id, cancellationToken);
            allOccurrences.AddRange(occs);
=======
            var memberOccs = allOccurrences
                .Where(o => o.AssignedUserId == member.UserId)
                .ToList();

            response.Members.Add(new MemberWorkload
            {
                UserId = member.UserId,
                DisplayName = member.User?.DisplayName ?? string.Empty,
                TotalChores = memberOccs.Count,
                TotalEstimatedMinutes = memberOccs.Sum(o => o.Chore?.EstimatedMinutes ?? 0),
                TotalKarma = memberOccs.Sum(o => o.Chore?.KarmaPoints ?? (o.SnapshotKarma > 0 ? o.SnapshotKarma : 0)),
                EasyCount = memberOccs.Count(o => o.Chore?.Difficulty == ChoreEffort.EASY),
                MediumCount = memberOccs.Count(o => o.Chore?.Difficulty == ChoreEffort.MEDIUM),
                HardCount = memberOccs.Count(o => o.Chore?.Difficulty == ChoreEffort.HARD),
            });
>>>>>>> Stashed changes
        }

        var assignedKarmaMap = activeMembers.ToDictionary(m => m.UserId, m => 0);
        foreach (var occ in allOccurrences.Where(o => o.AssignedUserId.HasValue))
        {
<<<<<<< Updated upstream
            if (assignedKarmaMap.ContainsKey(occ.AssignedUserId.Value))
=======
            var maxKarma = response.Members.Max(m => m.TotalKarma);
            var minKarma = response.Members.Min(m => m.TotalKarma);
            var avgKarma = response.Members.Average(m => m.TotalKarma);
            var karmaGap = maxKarma - minKarma;

            response.KarmaVariancePercentage = avgKarma > 0 
                ? Math.Round(((double)karmaGap / avgKarma) * 100.0, 2) 
                : 0.0;

            if (response.KarmaVariancePercentage > 20.0)
            {
                response.Warnings.Add(
                    $"Karma gap: variance of {response.KarmaVariancePercentage:F1}% exceeds 20% fairness threshold. Consider rebalancing.");
            }

            var maxMinutes = response.Members.Max(m => m.TotalEstimatedMinutes);
            var minMinutes = response.Members.Min(m => m.TotalEstimatedMinutes);
            var minuteGap = maxMinutes - minMinutes;

            if (minuteGap > AIAllocationConstants.FairnessThresholdMinutes)
>>>>>>> Stashed changes
            {
                assignedKarmaMap[occ.AssignedUserId.Value] += occ.SnapshotKarma;
            }
        }

<<<<<<< Updated upstream
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
=======
        // Include any warnings accumulated during allocation
        if (_seasonWarnings.TryGetValue(seasonId, out var allocWarnings))
        {
            lock (allocWarnings)
            {
                foreach (var w in allocWarnings)
                {
                    if (!response.Warnings.Contains(w))
                    {
                        response.Warnings.Add(w);
                    }
                }
            }
        }

        return response;
>>>>>>> Stashed changes
    }
}
