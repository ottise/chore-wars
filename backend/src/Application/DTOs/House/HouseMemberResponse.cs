using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.House;

public class HouseMemberResponse
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public HouseRole Role { get; set; }
    public HouseMemberStatus Status { get; set; }
}
