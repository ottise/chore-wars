using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Chore;

public class UpdateChoreRequest
{
    public Guid? SourceTemplateId { get; set; }
    public int DeadlineMinutes { get; set; } = 1439;
    public DateOnly? RecurrenceAnchor { get; set; }
    public List<DateOnly> CustomDates { get; set; } = new();
    public ChoreEffort Difficulty { get; set; } = ChoreEffort.MEDIUM;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int KarmaPoints { get; set; }
    public ChoreType Type { get; set; }
    public FrequencyType FrequencyType { get; set; }
    public int? FrequencyValue { get; set; }
    public System.DayOfWeek[]? FrequencyDays { get; set; }
}
