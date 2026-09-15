using System;
using System.Collections.Generic;

namespace ChoreWars.Application.DTOs.Season;

public class MemberAvailabilityRequest
{
    public Dictionary<DayOfWeek, bool> Availabilities { get; set; } = new();
}
