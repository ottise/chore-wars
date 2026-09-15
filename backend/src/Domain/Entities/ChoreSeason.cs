using System;
using System.Collections.Generic;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class ChoreSeason
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public SeasonStatus Status { get; set; }
    public AllocationMethod AllocationMethod { get; set; }

    public House House { get; set; } = null!;
    public ICollection<MemberAvailability> MemberAvailabilities { get; set; } = new List<MemberAvailability>();
    public ICollection<SeasonRanking> Rankings { get; set; } = new List<SeasonRanking>();
    public ICollection<Chore> Chores { get; set; } = new List<Chore>();
    public ICollection<SeasonConfirmation> Confirmations { get; set; } = new List<SeasonConfirmation>();
}
