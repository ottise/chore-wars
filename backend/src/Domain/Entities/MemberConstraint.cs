using System;

namespace ChoreWars.Domain.Entities;

public class MemberConstraint
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid HouseId { get; set; }
    public int MaxChoresPerWeek { get; set; } = 20;
    public int MaxEffortMinutesPerDay { get; set; } = 120;

    public User User { get; set; } = null!;
    public House House { get; set; } = null!;
}
