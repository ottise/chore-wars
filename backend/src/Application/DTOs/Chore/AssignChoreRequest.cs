using System;

namespace ChoreWars.Application.DTOs.Chore;

public class AssignChoreRequest
{
    public Guid UserId { get; set; }
    public Guid? OccurrenceId { get; set; }
}
