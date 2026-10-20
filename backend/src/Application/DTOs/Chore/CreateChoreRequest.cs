using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Chore;

public class CreateChoreRequest
{
    public bool AsRoutine { get; set; }
    public Guid? SourceTemplateId { get; set; }
    public int DeadlineMinutes { get; set; } = 1439;
    public DateOnly? RecurrenceAnchor { get; set; }
    public List<DateOnly> CustomDates { get; set; } = new();
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int KarmaPoints { get; set; }
    public ChoreType Type { get; set; }
    public FrequencyType FrequencyType { get; set; }
    public int? FrequencyValue { get; set; }
    public System.DayOfWeek[]? FrequencyDays { get; set; }
    public ChoreEffort Difficulty { get; set; } = ChoreEffort.MEDIUM;
    public int EstimatedMinutes { get; set; } = 30;

    public static int GetDefaultMinutes(ChoreEffort difficulty) => difficulty switch
    {
        ChoreEffort.EASY => 15,
        ChoreEffort.MEDIUM => 30,
        ChoreEffort.HARD => 45,
        _ => 30
    };
}
