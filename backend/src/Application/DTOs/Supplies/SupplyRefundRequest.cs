namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyRefundRequest(Guid ClientRequestId, decimal Amount, string Reference, string Reason);
