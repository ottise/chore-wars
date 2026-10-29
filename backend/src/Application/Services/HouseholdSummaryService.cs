using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;

public sealed class HouseholdSummaryService(IPersonalFinanceReadRepository read, IHouseAccessService access, IUnitOfWork uow, TimeProvider clock) : IHouseholdSummaryService
{
    public async Task<HouseholdSummaryResponse> ReadAsync(Guid house, Guid actor, DateOnly from, DateOnly to, Guid? season, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct);
        if (season.HasValue && (await uow.Seasons.GetByIdAsync(season.Value, ct))?.HouseId != house) throw new NotFoundException("Season not found in this household.");
        var range = PersonalFinanceService.Range(from, to);
        var all = await read.ChoresAsync(house, season, range.From, range.To, ct);
        var chores = all.Where(x => x.Status != ChoreOccurrenceStatus.SKIPPED).ToList();
        var now = clock.GetUtcNow().UtcDateTime;
        var done = chores.Where(x => x.Status == ChoreOccurrenceStatus.COMPLETED).ToList();
        bool Overdue(ChoreWars.Domain.Entities.ChoreOccurrence x) => x.Status != ChoreOccurrenceStatus.COMPLETED && x.DueDate < now;
        var members = await read.MembersAsync(house, ct);
        var names = members.GroupBy(x => x.UserId).ToDictionary(x => x.Key, x => x.First().User.DisplayName);
        foreach (var c in chores.Where(x => x.AssignedUserId.HasValue && x.AssignedUser != null)) names.TryAdd(c.AssignedUserId!.Value, c.AssignedUser!.DisplayName);
        var orders = await read.OrdersAsync(house, null, range.From, range.To, ct);
        var paid = orders.Where(x => x.PaidAt >= range.From && x.PaidAt < range.To).ToList();
        var debt = await read.DebtsAsync(house, null, range.From, range.To, ct);
        var internalPaid = debt.Transfers.Where(x => x.Status == InternalRepaymentStatus.CONFIRMED && x.RespondedAt >= range.From && x.RespondedAt < range.To).Sum(x => x.Amount);
        foreach (var d in debt.Debts.Where(x => x.Status == PaymentObligationStatus.PAID && x.PaidAt >= range.From && x.PaidAt < range.To))
            internalPaid += Math.Max(0, d.Amount + debt.Adjustments.Where(x => x.ObligationId == d.Id).Sum(x => x.Amount) - debt.Transfers.Where(x => x.ObligationId == d.Id && x.Status == InternalRepaymentStatus.CONFIRMED).Sum(x => x.Amount));
        return new(from, to, season, paid.Sum(x => x.RecordedPaidAmount ?? x.Total), paid.Count,
            orders.Count(x => x.PaidAt == null && x.Status != SupplyOrderStatus.CANCELLED), internalPaid,
            chores.Count, done.Count, done.Count(x => x.CompletedAt.HasValue && x.CompletedAt <= x.DueDate), chores.Count(Overdue),
            chores.Count(x => x.Status != ChoreOccurrenceStatus.COMPLETED && x.DueDate >= now), all.Count - chores.Count,
            names.Select(p => new MemberContributionResponse(p.Key, p.Value, chores.Count(x => x.AssignedUserId == p.Key),
                done.Count(x => x.CompletedByUserId == p.Key), chores.Where(x => x.AssignedUserId == p.Key).Sum(x => x.SnapshotMinutes),
                chores.Count(x => x.AssignedUserId == p.Key && x.Status != ChoreOccurrenceStatus.COMPLETED), chores.Count(x => x.AssignedUserId == p.Key && Overdue(x)))).OrderBy(x => x.Name).ToList(),
            paid.OrderByDescending(x => x.PaymentRecordedAt ?? x.PaidAt).Select(x => new SummaryOrderResponse(x.Id, x.SupplierName, x.PayerUserId, names.GetValueOrDefault(x.PayerUserId, "Former member"), x.RecordedPaidAmount ?? x.Total, x.PaymentRecordedAt ?? x.PaidAt!.Value, x.PaymentConfirmationSource ?? "PROVIDER_CONFIRMED")).ToList(),done.Count(x=>x.CompletedAt.HasValue),done.Count(x=>!x.CompletedByUserId.HasValue));
    }
}
