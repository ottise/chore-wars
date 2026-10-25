using System.ComponentModel.DataAnnotations;

namespace ChoreWars.Application.DTOs.AI;

public sealed class AIGenerateRequest
{
    public Guid ClientRequestId { get; set; }
    public Guid SeasonId { get; set; }
    public Guid? SourceOccurrenceId { get; set; }
    public Guid? SourceSeasonId { get; set; }
    [StringLength(8000)] public string? Text { get; set; }
    public int DeadlineMinutes { get; set; } = 30;
    public DateTimeOffset? ReadyBy { get; set; }
    [Range(1,10000)] public int? GuestCount { get; set; }
    public List<Guid> ParticipantIds { get; set; } = [];
    public List<string> Resources { get; set; } = [];
    public List<ScheduleAvailabilityChange> AvailabilityChanges { get; set; } = [];
    public string? ExpectedContextHash { get; set; }
    [Required, StringLength(20)] public string Kind { get; set; } = "ALLOCATION";
}
