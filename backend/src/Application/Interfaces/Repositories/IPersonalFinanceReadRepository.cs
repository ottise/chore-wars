using ChoreWars.Domain.Entities;
namespace ChoreWars.Application.Interfaces.Repositories;

public sealed record FinanceDebtData(List<PaymentObligation> Debts, List<InternalRepayment> Transfers, List<ObligationAdjustment> Adjustments);
public interface IPersonalFinanceReadRepository
{
    Task<FinanceDebtData> DebtsAsync(Guid house, Guid? actor, DateTime? from, DateTime? to, CancellationToken ct);
    Task<List<SupplyOrder>> OrdersAsync(Guid house, Guid? actor, DateTime from, DateTime to, CancellationToken ct);
    Task<List<ChoreOccurrence>> ChoresAsync(Guid house, Guid? season, DateTime from, DateTime to, CancellationToken ct);
    Task<List<HouseMember>> MembersAsync(Guid house, CancellationToken ct);
}
