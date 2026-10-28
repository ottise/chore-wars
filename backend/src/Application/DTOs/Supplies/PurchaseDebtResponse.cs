namespace ChoreWars.Application.DTOs.Supplies;
public sealed record PurchaseDebtResponse(Guid Id, Guid SourceOrderId, Guid DebtorUserId, string DebtorName, Guid CreditorUserId, string CreditorName, decimal OriginalAmount, decimal Adjustments, decimal ConfirmedAmount, decimal RemainingAmount, string Status, List<InternalRepaymentResponse> Repayments, string Type = "DEBT");
