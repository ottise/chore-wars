using System;

namespace ChoreWars.Domain.Entities;

public class SeasonRanking
{
    public Guid Id { get; set; }
    public Guid SeasonId { get; set; }
    public Guid UserId { get; set; }
    public int TotalKarma { get; set; }
    public int Rank { get; set; }
    public int ChoresCompleted { get; set; }

    public ChoreSeason Season { get; set; } = null!;
    public User User { get; set; } = null!;
}
