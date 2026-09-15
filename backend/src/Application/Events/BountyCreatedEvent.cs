using System;

namespace ChoreWars.Application.Events;

public class BountyCreatedEvent
{
    public Guid BountyId { get; set; }
    public Guid HouseId { get; set; }

    public BountyCreatedEvent(Guid bountyId, Guid houseId)
    {
        BountyId = bountyId;
        HouseId = houseId;
    }
}
