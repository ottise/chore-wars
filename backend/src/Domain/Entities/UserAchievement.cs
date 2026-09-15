using System;

namespace ChoreWars.Domain.Entities;

public class UserAchievement
{
    public Guid Id { get; set; }
    public Guid AchievementId { get; set; }
    public Guid UserId { get; set; }
    public DateTime UnlockedAt { get; set; }

    public Achievement Achievement { get; set; } = null!;
    public User User { get; set; } = null!;
}
