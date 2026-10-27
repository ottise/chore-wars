namespace ChoreWars.Application.Events;
public sealed record SupplyNotificationEvent(Guid HouseId, Guid ResourceId, string ResourceType, Guid ActorId, Guid? RecipientId, string Title, string Message)
{
    public Guid EventId { get; init; } = Guid.NewGuid();
}
