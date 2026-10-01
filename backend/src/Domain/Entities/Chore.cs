using System;
using System.Collections.Generic;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class Chore
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid SeasonId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int KarmaPoints { get; set; }
    public ChoreType Type { get; set; }
    public FrequencyType FrequencyType { get; set; }
    public int? FrequencyValue { get; set; }
    public ChoreEffort Difficulty { get; set; } = ChoreEffort.MEDIUM;
    public int EstimatedMinutes { get; set; } = 30;

    public House House { get; set; } = null!;
    public ChoreSeason Season { get; set; } = null!;
    public ICollection<ChoreOccurrence> Occurrences { get; set; } = new List<ChoreOccurrence>();
    public ICollection<ChoreFrequencyDay> FrequencyDays { get; set; } = new List<ChoreFrequencyDay>();
}
