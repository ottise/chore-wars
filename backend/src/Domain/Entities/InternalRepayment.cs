using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class InternalRepayment {
public Guid Id { get; set; }
public Guid ObligationId { get; set; }
public Guid ClientRequestId { get; set; }
public string Source { get; set; } = "DEBTOR_REPORTED";
public Guid? RecordedByUserId { get; set; }
public decimal Amount { get; set; }
public string Reference { get; set; } = "";
public InternalRepaymentStatus Status { get; set; }
public DateTime ReportedAt { get; set; }
public DateTime? RespondedAt { get; set; }
public string? ResponseReason { get; set; }
}
