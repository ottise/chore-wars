using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class ChoreOccurrence
{
    public Guid Id { get; set; }
    public Guid ChoreId { get; set; }
    public Guid AssignedUserId { get; set; }
    public DateTime DueDate { get; set; }
    public ChoreOccurrenceStatus Status { get; set; }
    public DateTime? CompletedAt { get; set; }
    public int PenaltyCount { get; set; }
    public string? ProofImageUrl { get; set; }

    public Chore Chore { get; set; } = null!;
    public User AssignedUser { get; set; } = null!;
}
