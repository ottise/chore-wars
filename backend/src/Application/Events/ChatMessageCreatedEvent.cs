namespace ChoreWars.Application.Events;

public sealed record ChatMessageCreatedEvent(Guid MessageId, Guid HouseId, Guid[] RecipientIds, Guid[] MentionedIds);
