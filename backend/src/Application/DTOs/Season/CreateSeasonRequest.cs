using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Season;

public class CreateSeasonRequest
{
    public string Name { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public AllocationMethod AllocationMethod { get; set; }
}
