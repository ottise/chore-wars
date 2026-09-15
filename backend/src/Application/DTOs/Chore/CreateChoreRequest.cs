using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Chore;

public class CreateChoreRequest
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int KarmaPoints { get; set; }
    public ChoreType Type { get; set; }
    public FrequencyType FrequencyType { get; set; }
    public int? FrequencyValue { get; set; }
    public System.DayOfWeek[]? FrequencyDays { get; set; }
}
