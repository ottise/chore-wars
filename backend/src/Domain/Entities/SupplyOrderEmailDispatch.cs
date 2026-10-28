using ChoreWars.Domain.Common.Constants;
namespace ChoreWars.Domain.Entities;
public sealed class SupplyOrderEmailDispatch
{
    public Guid Id { get; set; }
    public Guid OrderId { get; set; }
    public string Recipient { get; set; } = "";
    public string Subject { get; set; } = "";
    public string Body { get; set; } = "";
    public string State { get; set; } = OrderEmailState.Queued;
    public int Attempts { get; set; }
    public Guid? LeaseId { get; set; }
    public DateTime? LeaseUntil { get; set; }
    public DateTime? SentAt { get; set; }
    public string? ErrorCode { get; set; }
    public DateTime CreatedAt { get; set; }
}
