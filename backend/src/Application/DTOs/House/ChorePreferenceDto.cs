using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.House;

public class ChorePreferenceDto
{
    public Guid ChoreId { get; set; }
    public PreferenceType Type { get; set; }
}
