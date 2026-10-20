using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Season;

public class SeasonResponse
{
    public string? LastRejectionReason { get; set; }
    public int ScheduleRevision { get; set; }
    public List<SeasonConfirmationResponse> Confirmations { get; set; } = new();
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public SeasonStatus Status { get; set; }
    public AllocationMethod AllocationMethod { get; set; }
    public ConfirmationStatus? CurrentUserConfirmationStatus { get; set; }
    public int ConfirmedCount { get; set; }
    public int RequiredConfirmationCount { get; set; }
}

public class SeasonConfirmationResponse
{
    public Guid UserId { get; set; }
    public ConfirmationStatus Status { get; set; }
    public string? Reason { get; set; }
}
