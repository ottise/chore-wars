using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class ChoreOccurrence
{
    public ICollection<ChoreResponsibility> Responsibilities { get; set; } = new List<ChoreResponsibility>();
    public int SnapshotMinutes { get; set; }
    public ChoreEffort SnapshotDifficulty { get; set; }
    public DateTime? PlannedStartAt { get; set; }
    public Guid? CompletedByUserId { get; set; }
    public Guid Id { get; set; }
    public Guid ChoreId { get; set; }
    public Guid SeasonId { get; set; }
    public Guid? AssignedUserId { get; set; }
    public DateTime DueDate { get; set; }
    public ChoreOccurrenceStatus Status { get; set; }
    public DateTime? CompletedAt { get; set; }
    public int PenaltyCount { get; set; }
    public int SnapshotKarma { get; set; }
    public bool IsForcedReassigned { get; set; }
    public string? ProofImageUrl { get; set; }
    public Guid? EvidenceId { get; set; }
    public bool ReminderSent { get; set; }

    public Chore Chore { get; set; } = null!;
    public ChoreSeason Season { get; set; } = null!;
    public User? AssignedUser { get; set; }
}
