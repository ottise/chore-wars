using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class HouseMember
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid UserId { get; set; }
    public HouseRole Role { get; set; }
    public HouseMemberStatus Status { get; set; }
    public DateTime JoinedAt { get; set; }
    public int KarmaBalance { get; set; }

    public House House { get; set; } = null!;
    public User User { get; set; } = null!;
}
