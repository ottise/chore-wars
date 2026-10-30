using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
namespace ChoreWars.Application.Services;

public static class ChoreResponsibilityService
{
    public static async Task<ChoreResponsibility> EnsureAsync(IUnitOfWork uow, ChoreOccurrence occurrence, DateTime now, CancellationToken ct)
    {
        var current = occurrence.Responsibilities.SingleOrDefault(r => r.EndedAt == null);
        if (current != null) return current;
        var episode = new ChoreResponsibility { Id = Guid.NewGuid(), OccurrenceId = occurrence.Id, UserId = occurrence.AssignedUserId!.Value, Deadline = occurrence.DueDate, StartedAt = now, PenaltiesApplied = occurrence.PenaltyCount, Reason = "LEGACY" };
        occurrence.Responsibilities.Add(episode);
        await uow.ChoreOccurrences.AddResponsibilityAsync(episode, ct);
        return episode;
    }
    public static async Task AssignAsync(IUnitOfWork uow, ChoreOccurrence occurrence, Guid userId, string reason, DateTime deadline, DateTime now, CancellationToken ct)
    {
        if (occurrence.AssignedUserId.HasValue)
        {
            var previous = await EnsureAsync(uow, occurrence, now, ct);
            previous.EndedAt = now;
            // Flush the previous episode before inserting its replacement (filtered unique index).
            await uow.SaveChangesAsync(ct);
        }
        var episode = new ChoreResponsibility { Id = Guid.NewGuid(), OccurrenceId = occurrence.Id, UserId = userId, Reason = reason, StartedAt = now, Deadline = deadline };
        occurrence.Responsibilities.Add(episode);
        await uow.ChoreOccurrences.AddResponsibilityAsync(episode, ct);
        occurrence.AssignedUserId = userId;
        occurrence.DueDate = deadline;
        occurrence.PenaltyCount = 0;
        occurrence.Status = ChoreOccurrenceStatus.ASSIGNED;
        occurrence.ReminderSent = false;
        occurrence.IsForcedReassigned = reason == "FORCED_BOUNTY";
    }
}
