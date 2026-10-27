using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services.Supplies;

public static class SupplyCostSplitter
{
    public static Dictionary<Guid, decimal> Split(decimal total, IReadOnlyCollection<Guid> users)
    {
        if (users.Count is < 1 or > SupplyConstants.MaxMembers || users.Distinct().Count() != users.Count ||
            total <= 0 || total > SupplyConstants.MaxMoney || decimal.Truncate(total) != total)
            throw new DomainException("Choose unique participants and a valid VND total.");
        var ordered = users.Order().ToList();
        var part = decimal.Floor(total / ordered.Count);
        var remainder = (int)(total - part * ordered.Count);
        return ordered.Select((user, index) => (user, amount: part + (index < remainder ? 1 : 0)))
            .ToDictionary(x => x.user, x => x.amount);
    }
}
