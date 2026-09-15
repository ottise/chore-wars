using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Gamification;

public class RewardResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public RewardType Type { get; set; }
}
