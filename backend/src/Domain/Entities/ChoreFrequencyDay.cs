using System;

namespace ChoreWars.Domain.Entities;

public class ChoreFrequencyDay
{
    public Guid Id { get; set; }
    public Guid ChoreId { get; set; }
    public DayOfWeek DayOfWeek { get; set; }

    public Chore Chore { get; set; } = null!;
}
