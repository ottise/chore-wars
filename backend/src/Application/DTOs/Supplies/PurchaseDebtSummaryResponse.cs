namespace ChoreWars.Application.DTOs.Supplies;
public sealed record PurchaseDebtSummaryResponse(decimal Advanced, decimal PersonalCost, decimal Repaid, decimal Received, decimal Owe, decimal OwedToMe, List<PurchaseDebtResponse> Debts);
