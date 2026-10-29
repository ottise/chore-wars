using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Infrastructure.Repositories;

public sealed class PersonalFinanceReadRepository(AppDbContext db) : IPersonalFinanceReadRepository
{
    public async Task<FinanceDebtData> DebtsAsync(Guid house, Guid? actor, DateTime? from, DateTime? to, CancellationToken ct)
    {
        var query = db.PaymentObligations.AsNoTracking().Where(x => x.HouseId == house);
        if (actor.HasValue) query = query.Where(x => x.DebtorUserId == actor || x.CreditorUserId == actor);
        if (from.HasValue && to.HasValue) query = query.Where(x =>
            x.PaidAt >= from && x.PaidAt < to || db.InternalRepayments.Any(r => r.ObligationId == x.Id &&
                (r.ReportedAt >= from && r.ReportedAt < to || r.RespondedAt >= from && r.RespondedAt < to)));
        var debts = await query.Include(x => x.DebtorUser).Include(x => x.CreditorUser).ToListAsync(ct);
        var ids = debts.Select(x => x.Id).ToArray();
        return new(debts, await db.InternalRepayments.AsNoTracking().Where(x => ids.Contains(x.ObligationId)).ToListAsync(ct),
            await db.ObligationAdjustments.AsNoTracking().Where(x => ids.Contains(x.ObligationId)).ToListAsync(ct));
    }
    public Task<List<SupplyOrder>> OrdersAsync(Guid house, Guid? actor, DateTime from, DateTime to, CancellationToken ct) =>
        db.SupplyOrders.AsNoTracking().Where(x => x.HouseId == house && (!actor.HasValue || x.PayerUserId == actor) &&
            (x.CreatedAt >= from && x.CreatedAt < to || x.PaidAt >= from && x.PaidAt < to)).ToListAsync(ct);
    public Task<List<ChoreOccurrence>> ChoresAsync(Guid house, Guid? season, DateTime from, DateTime to, CancellationToken ct) =>
        db.ChoreOccurrences.AsNoTracking().Include(x => x.Chore).Include(x => x.AssignedUser)
            .Where(x => x.Chore.HouseId == house && (!season.HasValue || x.SeasonId == season) &&
                (x.Season.Status == ChoreWars.Domain.Enums.SeasonStatus.ACTIVE || x.Season.Status == ChoreWars.Domain.Enums.SeasonStatus.COMPLETED) && x.DueDate >= from && x.DueDate < to).ToListAsync(ct);
    public Task<List<HouseMember>> MembersAsync(Guid house, CancellationToken ct) => db.HouseMembers.AsNoTracking().Include(x => x.User).Where(x => x.HouseId == house).ToListAsync(ct);
}
