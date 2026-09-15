using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class RewardRedemption
{
    public Guid Id { get; set; }
    public Guid RewardId { get; set; }
    public Guid UserId { get; set; }
    public RewardRedemptionStatus Status { get; set; }
    public DateTime RedeemedAt { get; set; }
    public DateTime? UsedAt { get; set; }

    public Reward Reward { get; set; } = null!;
    public User User { get; set; } = null!;
}
