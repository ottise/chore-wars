namespace ChoreWars.Domain.Entities;
public sealed class SupplierRefund
{
    public Guid Id { get; set; }
    public Guid OrderId { get; set; }
    public Guid ClientRequestId { get; set; }
    public decimal Amount { get; set; }
    public string Reference { get; set; } = "";
    public string Reason { get; set; } = "";
    public DateTime ReportedAt { get; set; }
    public DateTime? ConfirmedAt { get; set; }
    public DateTime? RejectedAt { get; set; }
}
