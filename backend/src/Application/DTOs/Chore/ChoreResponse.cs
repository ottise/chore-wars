using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Chore;

public class ChoreResponse
{
    public int ScheduleRevision { get; set; }
    public string AssignmentStatus { get; set; } = string.Empty;
    public string? AssignmentReason { get; set; }
    public List<Guid> OccurrenceIds { get; set; } = new();
    public int AssignedCount { get; set; }
    public int UnassignedCount { get; set; }
    public Guid? SeasonId { get; set; }
    public Guid Id { get; set; }
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
    public DayOfWeek[] FrequencyDays { get; set; } = Array.Empty<DayOfWeek>();
    public ChoreEffort Difficulty { get; set; }
    public int EstimatedMinutes { get; set; }
}
