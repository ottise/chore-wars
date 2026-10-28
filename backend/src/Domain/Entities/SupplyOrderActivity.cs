namespace ChoreWars.Domain.Entities;
public sealed class SupplyOrderActivity
{
    public Guid Id { get; set; }
    public Guid OrderId { get; set; }
    public Guid? ActorUserId { get; set; }
    public string Kind { get; set; } = "";
    public DateTime RecordedAt { get; set; }
    public decimal? Amount { get; set; }
    public string? Reference { get; set; }
}
