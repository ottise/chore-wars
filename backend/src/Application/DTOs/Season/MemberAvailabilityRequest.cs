using System;
using System.Collections.Generic;

namespace ChoreWars.Application.DTOs.Season;

public class MemberAvailabilityRequest
{
    public Dictionary<int, List<AvailabilitySlotRequest>> Slots { get; set; } = new();
    public Dictionary<int, bool> Availabilities { get; set; } = new();
}

public class AvailabilitySlotRequest
{
    public int StartMinute { get; set; }
    public int EndMinute { get; set; }
}
