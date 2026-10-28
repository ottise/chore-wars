namespace ChoreWars.Application.DTOs.Supplies;
public sealed record RecordSupplyOrderPaymentRequest(Guid ClientRequestId, decimal Amount, string Reference = "");
