using System;

namespace ChoreWars.Application.Events;

public class SeasonEndedEvent
{
    public Guid SeasonId { get; set; }
    public Guid HouseId { get; set; }

    public SeasonEndedEvent(Guid seasonId, Guid houseId)
    {
        SeasonId = seasonId;
        HouseId = houseId;
    }
}
