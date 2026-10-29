using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.DTOs.Payments;

public sealed record PaymentHistoryEntryResponse(string Id, string Source, Guid SourceId, Guid? OrderId,
    string Direction, decimal Amount, string Counterparty, DateTime RecordedAt, string Status, string ConfirmationSource);
public sealed record PaymentHistoryResponse(decimal MoneyIn, decimal MoneyOut, int TotalCount, int Page, int PageSize, List<PaymentHistoryEntryResponse> Items);
public sealed record PersonalDebtSummaryResponse(decimal Owe, decimal OwedToMe, List<PurchaseDebtResponse> Debts);
