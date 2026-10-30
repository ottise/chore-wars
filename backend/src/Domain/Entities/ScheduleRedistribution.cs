namespace ChoreWars.Domain.Entities;

public sealed class ScheduleRedistribution
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid SeasonId { get; set; }
    public Guid ActorId { get; set; }
    public Guid TargetUserId { get; set; }
    public Guid ClientRequestId { get; set; }
    public string ResultJson { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
