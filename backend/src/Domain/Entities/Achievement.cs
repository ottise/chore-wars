using System;
using System.Collections.Generic;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class Achievement
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public AchievementConditionType ConditionType { get; set; }
    public int Threshold { get; set; }

    public House House { get; set; } = null!;
    public ICollection<UserAchievement> UserAchievements { get; set; } = new List<UserAchievement>();
}
