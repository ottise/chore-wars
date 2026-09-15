using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class ChoreBounty
{
    public Guid Id { get; set; }
    public Guid ChoreOccurrenceId { get; set; }
    public Guid PostedByUserId { get; set; }
    public decimal Amount { get; set; }
    public BountyStatus Status { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }

    public ChoreOccurrence ChoreOccurrence { get; set; } = null!;
    public User PostedByUser { get; set; } = null!;
}
