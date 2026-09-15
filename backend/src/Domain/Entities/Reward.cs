using System;
using System.Collections.Generic;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class Reward
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid SeasonId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public RewardType Type { get; set; }
    
    public House House { get; set; } = null!;
    public ChoreSeason Season { get; set; } = null!;
    public ICollection<RewardRedemption> Redemptions { get; set; } = new List<RewardRedemption>();
}
