using ChoreWars.Application.DTOs.Payments;
namespace ChoreWars.Application.Interfaces.Services;
public interface IPersonalFinanceService
{
    Task<PersonalDebtSummaryResponse> DebtsAsync(Guid house, Guid actor, CancellationToken ct);
    Task<PaymentHistoryResponse> HistoryAsync(Guid house, Guid actor, DateOnly from, DateOnly to, string direction, int page, int pageSize, CancellationToken ct);
}
