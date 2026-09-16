using System;

namespace ChoreWars.Application.Events;

public class DeadlineReminderEvent
{
    public Guid ChoreOccurrenceId { get; }
    public Guid AssignedUserId { get; }
    public Guid HouseId { get; }

    public DeadlineReminderEvent(Guid choreOccurrenceId, Guid assignedUserId, Guid houseId)
    {
        ChoreOccurrenceId = choreOccurrenceId;
        AssignedUserId = assignedUserId;
        HouseId = houseId;
    }
}
