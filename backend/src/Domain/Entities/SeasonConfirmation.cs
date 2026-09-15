using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class SeasonConfirmation
{
    public Guid Id { get; set; }
    public Guid SeasonId { get; set; }
    public Guid UserId { get; set; }
    public ConfirmationStatus Status { get; set; }
    public string? Reason { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ChoreSeason Season { get; set; } = null!;
    public User User { get; set; } = null!;
}
