namespace ChoreWars.Application.DTOs.Supplies;
public sealed record ConfirmRepaymentRequest(bool Confirm, string? Reason = null);
