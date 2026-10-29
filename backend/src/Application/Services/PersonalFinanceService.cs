using ChoreWars.Application.DTOs.Payments;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;

public sealed class PersonalFinanceService(IPersonalFinanceReadRepository read, IHouseAccessService access) : IPersonalFinanceService
{
    public static PurchaseDebtResponse Debt(PaymentObligation d, FinanceDebtData data)
    {
        var transfers = data.Transfers.Where(x => x.ObligationId == d.Id).ToList();
        var adjustments = data.Adjustments.Where(x => x.ObligationId == d.Id).Sum(x => x.Amount);
        var confirmed = transfers.Where(x => x.Status == InternalRepaymentStatus.CONFIRMED).Sum(x => x.Amount);
        if (d.Status == PaymentObligationStatus.PAID) confirmed = Math.Max(confirmed, d.Amount + adjustments);
        return new(d.Id, d.SourceOrderId, d.DebtorUserId, d.DebtorUser.DisplayName, d.CreditorUserId, d.CreditorUser.DisplayName,
            d.Amount, adjustments, confirmed, d.Status == PaymentObligationStatus.CANCELLED ? 0 : Math.Max(0, d.Amount + adjustments - confirmed), d.Status.ToString(),
            transfers.OrderByDescending(x => x.ReportedAt).Select(x => new InternalRepaymentResponse(x.Id, x.Amount, x.Reference, x.Status.ToString(), x.ReportedAt, x.RespondedAt, x.ResponseReason, Source: x.Source, RecordedByUserId: x.RecordedByUserId)).ToList(), Reason: d.Reason.ToString(), HouseId:d.HouseId);
    }
    public async Task<PersonalDebtSummaryResponse> DebtsAsync(Guid house, Guid actor, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct);
        var data = await read.DebtsAsync(house, actor, null, null, ct);
        var rows = data.Debts.Where(x => x.Status != PaymentObligationStatus.CANCELLED).Select(x => Debt(x, data)).OrderBy(x => x.RemainingAmount == 0).ThenBy(x => x.Id).ToList();
        return new(rows.Where(x => x.DebtorUserId == actor).Sum(x => x.RemainingAmount), rows.Where(x => x.CreditorUserId == actor).Sum(x => x.RemainingAmount), rows);
    }
    public static (DateTime From, DateTime To) Range(DateOnly from, DateOnly to)
    {
        if (from == DateOnly.MinValue || to < from || to.DayNumber - from.DayNumber > 365 || to == DateOnly.MaxValue) throw new DomainException("Choose a date range of up to one year.");
        return (ScheduleTime.Utc(from, 0), ScheduleTime.Utc(to.AddDays(1), 0));
    }
    public async Task<PaymentHistoryResponse> HistoryAsync(Guid house, Guid actor, DateOnly from, DateOnly to, string direction, int page, int pageSize, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct);
        var range = Range(from, to);
        if (page < 1 || page > 100000 || pageSize < 1 || pageSize > 100 || direction is not ("ALL" or "IN" or "OUT")) throw new DomainException("Invalid history filter or page.");
        var data = await read.DebtsAsync(house, actor, range.From, range.To, ct);
        var rows = new List<PaymentHistoryEntryResponse>();
        foreach (var d in data.Debts)
        {
            var transfers = data.Transfers.Where(x => x.ObligationId == d.Id).ToList();
            var counterparty = actor == d.DebtorUserId ? d.CreditorUser.DisplayName : d.DebtorUser.DisplayName;
            var flow = actor == d.DebtorUserId ? "OUT" : "IN";
            foreach (var r in transfers.Where(x => x.Status != InternalRepaymentStatus.REJECTED))
                rows.Add(new($"transfer:{r.Id}", d.Reason.ToString(), d.Id, d.SourceOrderId, flow, r.Amount, counterparty,
                    r.RespondedAt ?? r.ReportedAt, r.Status == InternalRepaymentStatus.CONFIRMED ? "CONFIRMED" : "PENDING_CONFIRMATION", r.Status == InternalRepaymentStatus.REPORTED ? "DEBTOR_REPORTED" : r.Source == "CREDITOR_RECORDED" ? "RECIPIENT_RECORDED" : "RECIPIENT_CONFIRMED"));
            // Legacy full settlements may exist without transfer rows. Only emit the unrepresented remainder.
            if (d.Status == PaymentObligationStatus.PAID && d.PaidAt.HasValue)
            {
                var remainder = Math.Max(0, d.Amount + data.Adjustments.Where(x => x.ObligationId == d.Id).Sum(x => x.Amount) - transfers.Where(x => x.Status == InternalRepaymentStatus.CONFIRMED).Sum(x => x.Amount));
                if (remainder > 0) rows.Add(new($"settlement:{d.Id}", d.Reason.ToString(), d.Id, d.SourceOrderId, flow, remainder, counterparty, d.PaidAt.Value, "CONFIRMED", "RECIPIENT_CONFIRMED"));
            }
        }
        foreach (var order in await read.OrdersAsync(house, actor, range.From, range.To, ct))
            if (order.PaidAt.HasValue) rows.Add(new($"order:{order.Id}", "ORDER", order.Id, order.Id, "OUT", order.RecordedPaidAmount ?? order.Total, order.SupplierName, order.PaymentRecordedAt ?? order.PaidAt.Value, "CONFIRMED", order.PaymentConfirmationSource ?? "PROVIDER_CONFIRMED"));
        var within = rows.Where(x => x.RecordedAt >= range.From && x.RecordedAt < range.To).ToList();
        var visible = within.Where(x => direction == "ALL" || x.Direction == direction).OrderByDescending(x => x.RecordedAt).ThenBy(x => x.Id).ToList();
        return new(within.Where(x => x.Status == "CONFIRMED" && x.Direction == "IN").Sum(x => x.Amount), within.Where(x => x.Status == "CONFIRMED" && x.Direction == "OUT").Sum(x => x.Amount), visible.Count, page, pageSize, visible.Skip((page - 1) * pageSize).Take(pageSize).ToList());
    }
}
