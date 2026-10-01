using System;
using System.Collections.Generic;

namespace ChoreWars.Application.DTOs.Season;

public class WorkloadSummaryResponse
{
    public List<MemberWorkload> Members { get; set; } = new();
    public List<string> Warnings { get; set; } = new();
}

public class MemberWorkload
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public int TotalChores { get; set; }
    public int TotalEstimatedMinutes { get; set; }
    public int EasyCount { get; set; }
    public int MediumCount { get; set; }
    public int HardCount { get; set; }
}
