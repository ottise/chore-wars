using System.Collections.Generic;

namespace ChoreWars.Application.DTOs.House;

public class SetMemberPreferencesRequest
{
    public List<ChorePreferenceDto> Preferences { get; set; } = new();
}
