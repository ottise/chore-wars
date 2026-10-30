using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Bounty;

public class BountyResponse
{
    public Guid? ClaimedByUserId { get; set; }
    public Guid? CancellationRequestedByUserId { get; set; }
    public Guid Id { get; set; }
    public Guid ChoreOccurrenceId { get; set; }
    public string ChoreName { get; set; } = string.Empty;
    public Guid PostedByUserId { get; set; }
    public string PostedByDisplayName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public BountyStatus Status { get; set; }
    public DateTime OccurrenceDueAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public Guid? AssignedUserId { get; set; }
    public string? NewAssigneeDisplayName { get; set; }
    public decimal? ForcedCompensationAmount { get; set; }
}
