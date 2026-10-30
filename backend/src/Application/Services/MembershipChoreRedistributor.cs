using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;

public sealed class MembershipChoreRedistributor(IUnitOfWork uow, TimeProvider clock,
    INotificationService notifications, IScheduleRedistributionStore? audit = null,
    IHouseMutationCoordinator? mutations = null) : IMembershipChoreRedistributor
{
    public async Task<List<RedistributionResult>> RedistributeAsync(Guid houseId, Guid newUserId, CancellationToken ct)
    {
        var results = new List<RedistributionResult>();
        var seasons = (await uow.Seasons.GetByHouseIdAsync(houseId, ct))
            .Where(s => s.Status is SeasonStatus.ACTIVE or SeasonStatus.DRAFT or SeasonStatus.REVIEWING).ToList();
        foreach (var season in seasons)
        {
            var plan = await PlanAsync(houseId, season, newUserId, ct);
            await ApplyAsync(plan, season, true, ct);
            await AuditAsync(plan with { Revision = season.ScheduleRevision }, newUserId, Guid.NewGuid(), ct);
            results.Add(plan with { Revision = season.ScheduleRevision });
        }
        return results;
    }

    public async Task<RedistributionResult> PreviewAsync(Guid houseId, Guid seasonId, Guid targetUserId, Guid actor, CancellationToken ct)
    {
        await AuthorizeAsync(houseId, actor, ct);
        var season = await SeasonAsync(houseId, seasonId, ct);
        return await PlanAsync(houseId, season, targetUserId, ct);
    }

    public async Task<RedistributionResult> ConfirmAsync(Guid houseId, Guid seasonId, ConfirmRedistributionRequest request, Guid actor, CancellationToken ct)
    {
        async Task<RedistributionResult> Apply()
        {
            await AuthorizeAsync(houseId, actor, ct);
            if (request.ClientRequestId == Guid.Empty) throw new DomainException("A request ID is required.");
            var previous = audit == null ? null : await audit.FindAsync(houseId, actor, request.ClientRequestId, ct);
            if (previous != null)
            {
                var saved = JsonSerializer.Deserialize<RedistributionResult>(previous.ResultJson)!;
                if (saved.SeasonId != seasonId || saved.TargetUserId != request.TargetUserId || saved.BaseRevision != request.ExpectedRevision || saved.ContextHash != request.ContextHash)
                    throw new ConflictException("The request ID was already used for another preview.");
                return saved;
            }
            var season = await SeasonAsync(houseId, seasonId, ct);
            var plan = await PlanAsync(houseId, season, request.TargetUserId, ct);
            if (plan.BaseRevision != request.ExpectedRevision || plan.ContextHash != request.ContextHash)
                throw new ConflictException("The schedule changed. Review a fresh preview before confirming.");
            await ApplyAsync(plan, season, false, ct);
            var result = plan with { Revision = season.ScheduleRevision };
            await AuditAsync(result, actor, request.ClientRequestId, ct);
            await uow.SaveChangesAsync(ct);
            return result;
        }
        if (mutations != null) return await mutations.RunAsync(houseId, Apply, ct);
        await uow.BeginTransactionAsync(ct);
        try { var result = await Apply(); await uow.CommitTransactionAsync(ct); return result; }
        catch { await uow.RollbackTransactionAsync(ct); throw; }
    }

    private async Task AuthorizeAsync(Guid houseId, Guid actor, CancellationToken ct)
    {
        var member = await uow.HouseMembers.GetByHouseAndUserIdAsync(houseId, actor, ct);
        if (member?.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER) throw new ForbiddenException("Only the owner can review and apply redistribution.");
        var house = await uow.Houses.GetByIdAsync(houseId, ct);
        if (house == null || house.IsArchived) throw new ConflictException("This household is read-only.");
    }
    private async Task<ChoreSeason> SeasonAsync(Guid houseId, Guid id, CancellationToken ct)
    {
        var season = await uow.Seasons.GetByIdAsync(id, ct) ?? throw new NotFoundException("Season not found.");
        if (season.HouseId != houseId) throw new NotFoundException("Season not found.");
        if (season.Status is not (SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.ACTIVE)) throw new ConflictException("This season is closed.");
        return season;
    }
    private async Task<RedistributionResult> PlanAsync(Guid houseId, ChoreSeason season, Guid target, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var members = (await uow.HouseMembers.GetByHouseIdAsync(houseId, ct)).Where(m => m.Status == HouseMemberStatus.ACTIVE).Select(m => m.UserId).Order().ToList();
        if (!members.Contains(target)) throw new ConflictException("The recipient is not an active household member.");
        var source = (await uow.ChoreOccurrences.GetBySeasonIdAsync(season.Id, ct)).OrderBy(o => o.Id).ToList();
        var weekly = (await uow.MemberAvailabilities.GetBySeasonIdAsync(season.Id, ct)).ToList();
        var exceptions = (await uow.MemberAvailabilities.GetExceptionsBySeasonAsync(season.Id, ct)).ToList();
        var limits = await uow.MemberConstraints.GetByUserAndHouseIdAsync(target, houseId, ct);
        var payments = (await uow.PaymentObligations.GetByHouseIdAsync(houseId, ct)).Where(p => p.OccurrenceId.HasValue && p.Status != PaymentObligationStatus.CANCELLED).Select(p => p.OccurrenceId!.Value).ToHashSet();
        var bounties = (await uow.ChoreBounties.GetBountiesByHouseIdAsync(houseId, ct)).Where(b => b.Status != BountyStatus.CANCELLED).Select(b => b.ChoreOccurrenceId).ToHashSet();
        var copies = source.Select(o => new ChoreOccurrence { Id = o.Id, Chore = o.Chore, ChoreId = o.ChoreId, AssignedUserId = o.AssignedUserId, DueDate = o.DueDate, PlannedStartAt = o.PlannedStartAt, Status = o.Status, SnapshotKarma = o.SnapshotKarma, SnapshotMinutes = o.SnapshotMinutes }).ToList();
        int Load(Guid user) => copies.Where(o => o.AssignedUserId == user && o.DueDate > now && o.Status is not (ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED)).Sum(o => Math.Max(1, o.SnapshotKarma));
        var changes = new List<RedistributionChange>();
        var reasons = new HashSet<string>();
        foreach (var original in source.OrderByDescending(o => o.AssignedUserId.HasValue ? Load(o.AssignedUserId.Value) : 0).ThenBy(o => o.DueDate).ThenBy(o => o.Id))
        {
            if (original.Chore.Type != ChoreType.NORMAL || original.AssignedUserId == target || original.AssignedUserId.HasValue && !members.Contains(original.AssignedUserId.Value)) continue;
            if (original.Status != ChoreOccurrenceStatus.ASSIGNED || original.DueDate <= now || original.PlannedStartAt <= now || original.PenaltyCount > 0 || original.IsForcedReassigned || original.EvidenceId.HasValue || !string.IsNullOrEmpty(original.ProofImageUrl) || payments.Contains(original.Id) || bounties.Contains(original.Id)) { reasons.Add("Protected, started, overdue or financially committed chores were kept unchanged."); continue; }
            var weight = Math.Max(1, original.SnapshotKarma);
            var difference = original.AssignedUserId.HasValue ? Load(original.AssignedUserId.Value) - Load(target) : int.MaxValue;
            if (difference < weight || difference == weight && Load(target) > 0) continue;
            var start = original.PlannedStartAt ?? original.DueDate.AddMinutes(-AllocationEligibilityService.Minutes(original));
            if (start <= now) { reasons.Add("The remaining time is too short for this chore."); continue; }
            var copy = copies.Single(o => o.Id == original.Id);
            var feasible = await ChoreSchedulingService.AvailableStartAsync(uow, houseId, copy, target, copies, weekly, exceptions, start, ct);
            if (feasible != start) { reasons.Add("Availability, overlapping work or workload limits prevent a transfer at the existing time."); continue; }
            changes.Add(new(original.Id, original.Chore.Name, original.AssignedUserId, target, start, original.DueDate));
            copy.AssignedUserId = target; copy.PlannedStartAt = start;
        }
        if (changes.Count == 0) reasons.Add(source.Count == 0 ? "Generate the season schedule before sharing its chores." : "No safe transfer would improve the recipient's share. Review availability and future chores.");
        var snapshot = JsonSerializer.Serialize(new
        {
            season.Id,
            season.Status,
            season.ScheduleRevision,
            members,
            tasks = source.Select(o => new { o.Id, o.AssignedUserId, o.DueDate, o.PlannedStartAt, o.Status, o.SnapshotKarma, o.SnapshotMinutes, o.PenaltyCount, o.EvidenceId, o.ProofImageUrl, o.IsForcedReassigned }),
            weekly = weekly.Where(a => a.UserId == target).OrderBy(a => a.DayOfWeek).Select(a => new { a.DayOfWeek, a.IsAvailable, slots = a.Slots.OrderBy(x => x.StartMinute).Select(x => new { x.StartMinute, x.EndMinute }) }),
            exceptions = exceptions.Where(e => e.UserId == target).OrderBy(e => e.LocalDate).Select(e => new { e.LocalDate, e.SlotsJson }),
            limits = limits == null ? null : new { limits.MaxChoresPerWeek, limits.MaxEffortMinutesPerDay },
            payments = payments.Order(),
            bounties = bounties.Order(),
            changes
        });
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(snapshot)));
        return new(houseId, season.Id, target, season.ScheduleRevision, season.ScheduleRevision, hash, changes, reasons.Order().ToList());
    }
    private async Task ApplyAsync(RedistributionResult plan, ChoreSeason season, bool joined, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var changed = new Dictionary<Guid, Guid>();
        foreach (var change in plan.Changes)
        {
            var task = (await uow.ChoreOccurrences.GetByIdAsync(change.OccurrenceId, ct))!;
            await ChoreResponsibilityService.AssignAsync(uow, task, change.ToUserId, joined ? "MEMBER_JOINED" : "REDISTRIBUTED", task.DueDate, now, ct);
            task.PlannedStartAt = change.PlannedStartAt; uow.ChoreOccurrences.Update(task);
            if (change.FromUserId.HasValue) changed.TryAdd(change.FromUserId.Value, task.Id); changed.TryAdd(change.ToUserId, task.Id);
        }
        if (plan.Changes.Count > 0 || joined && season.Status != SeasonStatus.ACTIVE)
        {
            season.ScheduleRevision++; uow.Seasons.Update(season);
            if (season.Status is SeasonStatus.REVIEWING or SeasonStatus.DRAFT)
            {
                await uow.SeasonConfirmations.DeleteBySeasonIdAsync(season.Id, ct);
                if (season.Status == SeasonStatus.REVIEWING)
                {
                    var members = (await uow.HouseMembers.GetByHouseIdAsync(plan.HouseId, ct)).Where(m => m.Status == HouseMemberStatus.ACTIVE);
                    foreach (var member in members) await uow.SeasonConfirmations.AddAsync(new SeasonConfirmation { Id = Guid.NewGuid(), SeasonId = season.Id, UserId = member.UserId, ScheduleRevision = season.ScheduleRevision, Status = ConfirmationStatus.PENDING, CreatedAt = now, UpdatedAt = now }, ct);
                }
            }
        }
        foreach (var (user, task) in changed) await notifications.CreateNotificationAsync(user, plan.HouseId, "Chore schedule updated", "Remaining chores were shared again. Check your updated assignments.", nameof(NotificationType.CHORE_ASSIGNED), "CHORE", task, ct);
        if (joined && !changed.ContainsKey(plan.TargetUserId)) await notifications.CreateNotificationAsync(plan.TargetUserId, plan.HouseId, "Household schedule", string.Join(" ", plan.Reasons), nameof(NotificationType.CHORE_ASSIGNED), "SEASON", season.Id, ct);
    }
    private async Task AuditAsync(RedistributionResult result, Guid actor, Guid request, CancellationToken ct)
    {
        if (audit != null) await audit.AddAsync(new ScheduleRedistribution { Id = Guid.NewGuid(), HouseId = result.HouseId, SeasonId = result.SeasonId, ActorId = actor, TargetUserId = result.TargetUserId, ClientRequestId = request, ResultJson = JsonSerializer.Serialize(result), CreatedAt = clock.GetUtcNow().UtcDateTime }, ct);
    }
}
