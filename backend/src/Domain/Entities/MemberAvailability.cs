using System;

namespace ChoreWars.Domain.Entities;

public class MemberAvailability
{
    public Guid Id { get; set; }
    public Guid SeasonId { get; set; }
    public Guid UserId { get; set; }
    public DayOfWeek DayOfWeek { get; set; }
    public bool IsAvailable { get; set; }

    public ChoreSeason Season { get; set; } = null!;
    public User User { get; set; } = null!;
}
