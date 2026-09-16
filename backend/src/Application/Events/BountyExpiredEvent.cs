using System;

namespace ChoreWars.Application.Events;

public class BountyExpiredEvent
{
    public Guid BountyId { get; set; }
    public Guid OccurrenceId { get; set; }
    public Guid PostedByUserId { get; set; }
    public Guid HouseId { get; set; }

    public BountyExpiredEvent(Guid bountyId, Guid occurrenceId, Guid postedByUserId, Guid houseId)
    {
        BountyId = bountyId;
        OccurrenceId = occurrenceId;
        PostedByUserId = postedByUserId;
        HouseId = houseId;
    }
}
