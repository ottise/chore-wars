using System;
using System.Collections.Generic;

namespace ChoreWars.Domain.Entities;

public class House
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string InviteCode { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; }

    public ICollection<HouseMember> Members { get; set; } = new List<HouseMember>();
    public ICollection<ChoreSeason> Seasons { get; set; } = new List<ChoreSeason>();
    public ICollection<Chore> Chores { get; set; } = new List<Chore>();
}
