using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Chore;

public class ChoreOccurrenceResponse
{
    public Guid Id { get; set; }
    public Guid ChoreId { get; set; }
    public string ChoreName { get; set; } = string.Empty;
    public Guid AssignedUserId { get; set; }
    public string AssignedUserDisplayName { get; set; } = string.Empty;
    public DateTime DueDate { get; set; }
    public ChoreOccurrenceStatus Status { get; set; }
}
