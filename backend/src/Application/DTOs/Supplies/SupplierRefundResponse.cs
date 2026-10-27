namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplierRefundResponse(Guid Id, decimal Amount, string Reference, string Reason, DateTime ReportedAt, DateTime? ConfirmedAt, DateTime? RejectedAt);
