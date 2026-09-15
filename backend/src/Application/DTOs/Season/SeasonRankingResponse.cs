using System;

namespace ChoreWars.Application.DTOs.Season;

public class SeasonRankingResponse
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public int TotalKarma { get; set; }
    public int Rank { get; set; }
    public int ChoresCompleted { get; set; }
}
