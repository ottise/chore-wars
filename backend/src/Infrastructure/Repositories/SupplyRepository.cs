using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.Repositories;

public sealed class SupplyRepository(AppDbContext db) : ISupplyRepository
{
    private IQueryable<SupplyOrder> Orders => db.SupplyOrders.Include(x => x.Lines).Include(x => x.Shares).Include(x => x.EmailDispatch).Include(x => x.Activities).AsSplitQuery();
    public Task<List<Supplier>> SuppliersAsync(CancellationToken ct) => db.Suppliers.Where(x => x.Active).OrderBy(x => x.Name).ToListAsync(ct);
    public Task<Supplier?> SupplierAsync(Guid id, CancellationToken ct) => db.Suppliers.SingleOrDefaultAsync(x => x.Id == id, ct);
    public Task<Supplier?> OperatorAsync(Guid actor, CancellationToken ct) => db.Suppliers.SingleOrDefaultAsync(x => x.OperatorUserId == actor, ct);
    public Task<List<SupplyProduct>> ProductsAsync(Guid supplier, CancellationToken ct) => db.SupplyProducts.Where(x => x.SupplierId == supplier).OrderBy(x => x.Name).ToListAsync(ct);
    public Task<SupplyProduct?> ProductAsync(Guid id, CancellationToken ct) => db.SupplyProducts.SingleOrDefaultAsync(x => x.Id == id, ct);
    public async Task ReserveAsync(Guid product, int quantity, CancellationToken ct)
    {
        var affected = await db.SupplyProducts.Where(x => x.Id == product && x.Active && x.AvailableQuantity >= quantity)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.AvailableQuantity, x => x.AvailableQuantity - quantity), ct);
        if (affected != 1) throw new ConflictException("The requested stock is no longer available.");
    }
    public async Task ReleaseAsync(Guid product, int quantity, CancellationToken ct) =>
        await db.SupplyProducts.Where(x => x.Id == product).ExecuteUpdateAsync(s => s.SetProperty(x => x.AvailableQuantity, x => x.AvailableQuantity + quantity), ct);
    public Task<SupplyOrder?> OrderAsync(Guid id, CancellationToken ct) => Orders.SingleOrDefaultAsync(x => x.Id == id, ct);
    public async Task<SupplyOrderEmailDispatch?> ClaimEmailAsync(DateTime now, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var item = await db.SupplyOrderEmailDispatches.FromSqlInterpolated($"SELECT * FROM \"SupplyOrderEmailDispatches\" WHERE \"State\" = 'QUEUED' OR (\"State\" = 'SENDING' AND \"LeaseUntil\" < {now}) ORDER BY \"CreatedAt\" LIMIT 1 FOR UPDATE SKIP LOCKED").SingleOrDefaultAsync(ct);
        if (item == null) { await transaction.CommitAsync(ct); return null; }
        if (item.State == ChoreWars.Domain.Common.Constants.OrderEmailState.Sending)
        {
            item.State = ChoreWars.Domain.Common.Constants.OrderEmailState.Unknown; item.LeaseId = null; item.LeaseUntil = null; item.ErrorCode = "WORKER_RESULT_UNCERTAIN";
            db.SupplyOrderActivities.Add(new() { Id = Guid.NewGuid(), OrderId = item.OrderId, Kind = item.State, RecordedAt = now });
            await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct); return null;
        }
        item.State = ChoreWars.Domain.Common.Constants.OrderEmailState.Sending; item.LeaseId = Guid.NewGuid(); item.LeaseUntil = now.AddMinutes(2); item.Attempts++;
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct); return item;
    }
    public async Task CompleteEmailAsync(Guid id, Guid leaseId, string state, string? errorCode, DateTime now, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var item = await db.SupplyOrderEmailDispatches.SingleOrDefaultAsync(x => x.Id == id && x.LeaseId == leaseId && x.State == ChoreWars.Domain.Common.Constants.OrderEmailState.Sending, ct);
        if (item == null) { await transaction.CommitAsync(ct); return; }
        item.State = state; item.ErrorCode = errorCode; item.LeaseUntil = null;
        if (state == ChoreWars.Domain.Common.Constants.OrderEmailState.Sent) item.SentAt = now;
        db.SupplyOrderActivities.Add(new() { Id = Guid.NewGuid(), OrderId = item.OrderId, Kind = state, RecordedAt = now });
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);
    }
    public Task<SupplyOrder?> RequestAsync(Guid house, Guid actor, Guid request, CancellationToken ct) => Orders.SingleOrDefaultAsync(x => x.HouseId == house && x.CreatorUserId == actor && x.ClientRequestId == request, ct);
    public Task<List<SupplyOrder>> OrdersAsync(Guid? house, Guid? supplier, CancellationToken ct) => Orders
        .Where(x => (!house.HasValue || x.HouseId == house) && (!supplier.HasValue || x.SupplierId == supplier))
        .OrderByDescending(x => x.CreatedAt).Take(200).ToListAsync(ct);
    public Task<SupplierPayment?> PaymentAsync(Guid id, CancellationToken ct) => db.SupplierPayments.SingleOrDefaultAsync(x => x.Id == id, ct);
    public Task<SupplierPayment?> PaymentCodeAsync(long code, CancellationToken ct) => db.SupplierPayments.SingleOrDefaultAsync(x => x.OrderCode == code, ct);
    public Task<List<SupplierPayment>> PaymentsAsync(Guid order, CancellationToken ct) => db.SupplierPayments.Where(x => x.OrderId == order).OrderByDescending(x => x.CreatedAt).ToListAsync(ct);
    public Task<List<SupplierPayment>> PendingPaymentsAsync(DateTime now, CancellationToken ct) => db.SupplierPayments
        .Where(x => x.Status == SupplierPaymentStatus.CREATING || x.Status == SupplierPaymentStatus.PENDING || x.Status == SupplierPaymentStatus.EXPIRED)
        .OrderBy(x => x.CreatedAt).Take(100).ToListAsync(ct);
    public Task<bool> ReceiptExistsAsync(string reference, CancellationToken ct) => db.PaymentWebhookReceipts.AnyAsync(x => x.Reference == reference, ct);
    public Task<List<InternalRepayment>> RepaymentsAsync(Guid obligation, CancellationToken ct) => db.InternalRepayments.Where(x => x.ObligationId == obligation).OrderByDescending(x => x.ReportedAt).ToListAsync(ct);
    public Task<List<ObligationAdjustment>> AdjustmentsAsync(Guid obligation, CancellationToken ct) => db.ObligationAdjustments.Where(x => x.ObligationId == obligation).ToListAsync(ct);
    public Task<List<SupplySchedule>> SchedulesAsync(Guid house, CancellationToken ct) => db.SupplySchedules.Where(x => x.HouseId == house).OrderBy(x => x.NextDueAt).ToListAsync(ct);
    public Task<SupplySchedule?> ScheduleAsync(Guid id, CancellationToken ct) => db.SupplySchedules.SingleOrDefaultAsync(x => x.Id == id, ct);
    public Task<List<Guid>> DueSchedulesAsync(DateTime now, CancellationToken ct) => db.SupplySchedules.Where(x => x.Enabled && x.NextDueAt <= now && (x.SnoozedUntil == null || x.SnoozedUntil <= now)).OrderBy(x => x.NextDueAt).Select(x => x.Id).Take(100).ToListAsync(ct);
    public Task<bool> ReminderExistsAsync(Guid schedule, DateTime occurrence, CancellationToken ct) => db.SupplyReminderDeliveries.AnyAsync(x => x.ScheduleId == schedule && x.OccurrenceAt == occurrence, ct);
    public Task<List<Guid>> ExpiredOrdersAsync(DateTime now,CancellationToken ct) => db.SupplyOrders.Where(x=>x.Status==SupplyOrderStatus.APPROVED && x.QuoteExpiresAt<=now && !db.SupplierPayments.Any(p=>p.OrderId==x.Id)).Select(x=>x.Id).Take(100).ToListAsync(ct);
    public Task<UserBankAccount?> BankAsync(Guid user, CancellationToken ct) => db.UserBankAccounts.SingleOrDefaultAsync(x => x.UserId == user, ct);
    public void Add(Supplier value) => db.Suppliers.Add(value);
    public Task<List<SupplierRefund>> RefundsAsync(Guid order, CancellationToken ct) => db.SupplierRefunds.Where(x=>x.OrderId==order).OrderByDescending(x=>x.ReportedAt).ToListAsync(ct);
    public void Add(SupplierRefund value) => db.SupplierRefunds.Add(value);
    public Task<List<SupplyDispute>> DisputesAsync(Guid order,CancellationToken ct)=>db.SupplyDisputes.Where(x=>x.OrderId==order).OrderByDescending(x=>x.CreatedAt).ToListAsync(ct);
    public void Add(SupplyDispute value)=>db.SupplyDisputes.Add(value);
    public void Add(SupplyProduct value) => db.SupplyProducts.Add(value);
    public void Add(SupplyOrder value) => db.SupplyOrders.Add(value);
    public void Add(SupplyOrderActivity value) => db.SupplyOrderActivities.Add(value);
    public void Add(SupplierPayment value) => db.SupplierPayments.Add(value);
    public void Add(PaymentWebhookReceipt value) => db.PaymentWebhookReceipts.Add(value);
    public void Add(InternalRepayment value) => db.InternalRepayments.Add(value);
    public void Add(ObligationAdjustment value) => db.ObligationAdjustments.Add(value);
    public void Add(SupplySchedule value) => db.SupplySchedules.Add(value);
    public void Add(SupplyReminderDelivery value) => db.SupplyReminderDeliveries.Add(value);
    public void Add(UserBankAccount value) => db.UserBankAccounts.Add(value);
}
