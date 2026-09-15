using System;

namespace ChoreWars.Application.Events;

public class BountyAcceptedEvent
{
    public Guid BountyId { get; set; }
    public Guid AcceptedByUserId { get; set; }

    public BountyAcceptedEvent(Guid bountyId, Guid acceptedByUserId)
    {
        BountyId = bountyId;
        AcceptedByUserId = acceptedByUserId;
    }
}
