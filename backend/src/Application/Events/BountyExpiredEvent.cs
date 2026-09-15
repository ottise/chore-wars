using System;

namespace ChoreWars.Application.Events;

public class BountyExpiredEvent
{
    public Guid BountyId { get; set; }
    public Guid OccurrenceId { get; set; }

    public BountyExpiredEvent(Guid bountyId, Guid occurrenceId)
    {
        BountyId = bountyId;
        OccurrenceId = occurrenceId;
    }
}
