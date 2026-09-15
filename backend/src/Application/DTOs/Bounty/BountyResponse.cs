using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Bounty;

public class BountyResponse
{
    public Guid Id { get; set; }
    public Guid ChoreOccurrenceId { get; set; }
    public string ChoreName { get; set; } = string.Empty;
    public Guid PostedByUserId { get; set; }
    public string PostedByDisplayName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public BountyStatus Status { get; set; }
    public DateTime ExpiresAt { get; set; }
}
