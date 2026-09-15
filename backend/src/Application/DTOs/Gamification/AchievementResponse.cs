using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Gamification;

public class AchievementResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public AchievementConditionType ConditionType { get; set; }
    public int Threshold { get; set; }
}
