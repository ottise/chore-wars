using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.House;

public class MemberPreferenceResponse
{
    public Guid ChoreId { get; set; }
    public string ChoreName { get; set; } = string.Empty;
    public PreferenceType Type { get; set; }
}
