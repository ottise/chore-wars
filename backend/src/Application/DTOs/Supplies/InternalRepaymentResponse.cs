namespace ChoreWars.Application.DTOs.Supplies;
public sealed record InternalRepaymentResponse(Guid Id, decimal Amount, string Reference, string Status, DateTime ReportedAt, DateTime? RespondedAt, string? ResponseReason, string Type = "DEBT");
