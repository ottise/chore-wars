using System;

namespace ChoreWars.Application.Events;

public class ChoreOverdueEvent
{
    public Guid OccurrenceId { get; set; }
    public Guid UserId { get; set; }
    public Guid HouseId { get; set; }

    public ChoreOverdueEvent(Guid occurrenceId, Guid userId, Guid houseId)
    {
        OccurrenceId = occurrenceId;
        UserId = userId;
        HouseId = houseId;
    }
}
