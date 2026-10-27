namespace ChoreWars.Application.DTOs.Supplies;
public sealed record ReportRepaymentRequest(Guid ClientRequestId, decimal Amount, string Reference);
