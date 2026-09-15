using System;
using System.Collections.Generic;
using ChoreWars.Application.Events;

namespace ChoreWars.Infrastructure.Messaging.Kafka;

public static class KafkaTopics
{
    public const string CHORE_COMPLETED = "chore.completed";
    public const string BOUNTY_CREATED = "bounty.created";
    public const string BOUNTY_ACCEPTED = "bounty.accepted";
    public const string CHORE_OVERDUE = "chore.overdue";
    public const string BOUNTY_EXPIRED = "bounty.expired";
    public const string SEASON_ENDED = "season.ended";

    public static readonly IReadOnlyDictionary<Type, string> EventTopicMap = new Dictionary<Type, string>
    {
        { typeof(ChoreCompletedEvent), CHORE_COMPLETED },
        { typeof(BountyCreatedEvent), BOUNTY_CREATED },
        { typeof(BountyAcceptedEvent), BOUNTY_ACCEPTED },
        { typeof(ChoreOverdueEvent), CHORE_OVERDUE },
        { typeof(BountyExpiredEvent), BOUNTY_EXPIRED },
        { typeof(SeasonEndedEvent), SEASON_ENDED }
    };
}
