using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;
public sealed class PersonalFinanceTests
{
    private static async Task<Guid> Debt(PostgresFixture f, CoreConcurrencyTests.Data seed, PaymentObligationReason reason = PaymentObligationReason.BOUNTY_PAYMENT)
    {
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var id=Guid.NewGuid();db.PaymentObligations.Add(new(){Id=id,HouseId=seed.HouseId,DebtorUserId=seed.Users[1],CreditorUserId=seed.Users[0],Amount=100000,Reason=reason,Status=PaymentObligationStatus.PENDING,CreatedAt=DateTime.UtcNow,OccurrenceId=seed.OccurrenceId});await db.SaveChangesAsync();return id;
    }
    [PostgresFact]
    public async Task PartialTransfersNeedRecipientConsentAndHistoryDoesNotDoubleCountHouseholdSpending()
    {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);var id=await Debt(f,seed);
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var supplier=new Supplier{Id=Guid.NewGuid(),HouseId=seed.HouseId,Name="Shop"};db.Suppliers.Add(supplier);
        db.SupplyOrders.Add(new(){Id=Guid.NewGuid(),HouseId=seed.HouseId,SupplierId=supplier.Id,SupplierName="Rice shop",CreatorUserId=seed.Users[0],PayerUserId=seed.Users[0],ClientRequestId=Guid.NewGuid(),Total=300000,RecordedPaidAmount=300000,PaymentConfirmationSource="USER_REPORTED",CreatedAt=DateTime.UtcNow,PaidAt=DateTime.UtcNow,PaymentRecordedAt=DateTime.UtcNow,Status=SupplyOrderStatus.PAID,Workflow=SupplyOrderWorkflow.SIMPLE_CONTACT});await db.SaveChangesAsync();
        var service=scope.ServiceProvider.GetRequiredService<IInternalRepaymentService>();
        var receipt=new ReportRepaymentRequest(Guid.NewGuid(),40000,"");
        var first=await service.RecordReceiptAsync(id,seed.Users[0],receipt,default);Assert.Equal(60000,first.RemainingAmount);
        Assert.Equal(60000,(await service.RecordReceiptAsync(id,seed.Users[0],receipt,default)).RemainingAmount);
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.RecordReceiptAsync(id,seed.Users[1],new(Guid.NewGuid(),10000,""),default));
        var report=await service.ReportAsync(id,seed.Users[1],new(Guid.NewGuid(),60000,"Bank reference"),default);
        var pending=Assert.Single(report.Repayments,x=>x.Status=="REPORTED");Assert.Equal(60000,report.RemainingAmount);
        await Assert.ThrowsAsync<ConflictException>(()=>service.RecordReceiptAsync(id,seed.Users[0],new(Guid.NewGuid(),60000,""),default));
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.RespondAsync(id,pending.Id,seed.Users[1],new(true),default));
        var finance=scope.ServiceProvider.GetRequiredService<IPersonalFinanceService>();
        var today=DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        var before=await finance.HistoryAsync(seed.HouseId,seed.Users[0],today.AddDays(-1),today.AddDays(1),"ALL",1,30,default);
        Assert.Equal(40000,before.MoneyIn);Assert.Contains(before.Items,x=>x.Status=="PENDING_CONFIRMATION");
        var paid=await service.RespondAsync(id,pending.Id,seed.Users[0],new(true),default);Assert.Equal(0,paid.RemainingAmount);
        await service.RespondAsync(id,pending.Id,seed.Users[0],new(true),default);
        var history=await finance.HistoryAsync(seed.HouseId,seed.Users[0],today.AddDays(-1),today.AddDays(1),"ALL",1,30,default);
        Assert.Equal(100000,history.MoneyIn);Assert.Equal(300000,history.MoneyOut);Assert.Equal(3,history.TotalCount);
        var b=await finance.HistoryAsync(seed.HouseId,seed.Users[1],today.AddDays(-1),today.AddDays(1),"OUT",1,1,default);Assert.Equal(100000,b.MoneyOut);Assert.Equal(2,b.TotalCount);Assert.Single(b.Items);
        Assert.Empty((await finance.HistoryAsync(seed.HouseId,seed.Users[2],today.AddDays(-1),today.AddDays(1),"ALL",1,30,default)).Items);
        var summary=await scope.ServiceProvider.GetRequiredService<IHouseholdSummaryService>().ReadAsync(seed.HouseId,seed.Users[2],today.AddDays(-1),today.AddDays(1),null,default);
        Assert.Equal(300000,summary.ExternalPayments);Assert.Equal(100000,summary.InternalTransfers);
        Assert.Equal("CREDITOR_RECORDED",(await db.InternalRepayments.SingleAsync(x=>x.ClientRequestId==receipt.ClientRequestId)).Source);
    }
    [PostgresFact]
    public async Task DebtsStayPrivateAndCompensationStillRequiresCompletedWork()
    {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);var other=await CoreConcurrencyTests.Seed(f);var id=await Debt(f,seed,PaymentObligationReason.FORCED_REASSIGNMENT);
        await using var scope=f.Services.CreateAsyncScope();var service=scope.ServiceProvider.GetRequiredService<IInternalRepaymentService>();
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.ReadAsync(id,seed.Users[2],default));
        var finance=scope.ServiceProvider.GetRequiredService<IPersonalFinanceService>();
        await Assert.ThrowsAsync<ForbiddenException>(()=>finance.DebtsAsync(seed.HouseId,other.Users[0],default));
        await Assert.ThrowsAsync<ConflictException>(()=>service.RecordReceiptAsync(id,seed.Users[0],new(Guid.NewGuid(),100000,""),default));
        var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();var occurrence=await db.ChoreOccurrences.SingleAsync(x=>x.Id==seed.OccurrenceId);occurrence.Status=ChoreOccurrenceStatus.COMPLETED;occurrence.CompletedAt=DateTime.UtcNow;occurrence.CompletedByUserId=seed.Users[0];await db.SaveChangesAsync();
        var paid=await service.RecordReceiptAsync(id,seed.Users[0],new(Guid.NewGuid(),100000,""),default);Assert.Equal("PAID",paid.Status);Assert.Equal(0,paid.RemainingAmount);
        Assert.Equal(0,(await finance.DebtsAsync(seed.HouseId,seed.Users[1],default)).Owe);
    }
    [PostgresFact]
    public async Task RejectionPreservesDebtAndLegacySettlementCannotBypassPartialTransfers()
    {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);var id=await Debt(f,seed);
        await using var scope=f.Services.CreateAsyncScope();var service=scope.ServiceProvider.GetRequiredService<IInternalRepaymentService>();
        var report=await service.ReportAsync(id,seed.Users[1],new(Guid.NewGuid(),20000,""),default);
        var transfer=Assert.Single(report.Repayments);
        await Assert.ThrowsAsync<ConflictException>(()=>scope.ServiceProvider.GetRequiredService<IBountyService>().SettlePaymentAsync(id,seed.Users[0]));
        var rejected=await service.RespondAsync(id,transfer.Id,seed.Users[0],new(false,"Not received"),default);Assert.Equal(100000,rejected.RemainingAmount);
        await Assert.ThrowsAsync<ConflictException>(()=>service.RespondAsync(id,transfer.Id,seed.Users[0],new(true),default));
    }
    [PostgresFact]
    public async Task ConcurrentReportAndReceiptCannotRecordTheSameRemainingMoneyTwice()
    {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);var id=await Debt(f,seed);
        async Task<bool> Run(bool receipt){await using var scope=f.Services.CreateAsyncScope();var service=scope.ServiceProvider.GetRequiredService<IInternalRepaymentService>();try{if(receipt)await service.RecordReceiptAsync(id,seed.Users[0],new(Guid.NewGuid(),100000,""),default);else await service.ReportAsync(id,seed.Users[1],new(Guid.NewGuid(),100000,""),default);return true;}catch(ConflictException){return false;}}
        var results=await Task.WhenAll(Run(true),Run(false));Assert.Single(results,x=>x);
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();Assert.Single(await db.InternalRepayments.ToListAsync());
        var debt=await read.ServiceProvider.GetRequiredService<IInternalRepaymentService>().ReadAsync(id,seed.Users[0],default);Assert.InRange(debt.ConfirmedAmount,0,100000);
    }
    [PostgresFact]
    public async Task MigrationBackfillsOnlyTheActualDebtorAsAuthorOfExistingTransferReports()
    {
        await using var f=await PostgresFixture.CreateAsync();
        var seed=await CoreConcurrencyTests.Seed(f);var id=await Debt(f,seed);var transfer=Guid.NewGuid();
        await using(var down=f.Services.CreateAsyncScope())await down.ServiceProvider.GetRequiredService<AppDbContext>().GetService<IMigrator>().MigrateAsync("20261028112536_AddHouseholdShopContacts");
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();var request=Guid.NewGuid();var now=DateTime.UtcNow;
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"InternalRepayments\" (\"Id\",\"ObligationId\",\"ClientRequestId\",\"Amount\",\"Reference\",\"Status\",\"ReportedAt\") VALUES ({transfer},{id},{request},{20000},'legacy','REPORTED',{now})");
        await db.GetService<IMigrator>().MigrateAsync();
        Assert.All(await db.Users.ToListAsync(), user => Assert.NotNull(user.EmailVerifiedAt));
        var row=await db.InternalRepayments.SingleAsync();Assert.Equal(seed.Users[1],row.RecordedByUserId);Assert.Equal("DEBTOR_REPORTED",row.Source);Assert.Equal(20000,row.Amount);Assert.Equal(InternalRepaymentStatus.REPORTED,row.Status);
    }
    [PostgresFact]
    public async Task SummaryExcludesDraftPlansAndDoesNotInventMissingCompletionAuthorsOrTimes()
    {
        await using var f=await PostgresFixture.CreateAsync();var draft=await CoreConcurrencyTests.Seed(f,SeasonStatus.DRAFT);var active=await CoreConcurrencyTests.Seed(f);
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var row=await db.ChoreOccurrences.SingleAsync(x=>x.Id==active.OccurrenceId);row.Status=ChoreOccurrenceStatus.COMPLETED;row.CompletedAt=null;row.CompletedByUserId=null;await db.SaveChangesAsync();
        var service=scope.ServiceProvider.GetRequiredService<IHouseholdSummaryService>();var day=DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        Assert.Equal(0,(await service.ReadAsync(draft.HouseId,draft.Users[0],day.AddDays(-1),day.AddDays(1),null,default)).Assigned);
        var result=await service.ReadAsync(active.HouseId,active.Users[0],day.AddDays(-1),day.AddDays(1),active.SeasonId,default);
        Assert.Equal(1,result.Completed);Assert.Equal(0,result.CompletionTimingKnown);Assert.Equal(1,result.CompletionAuthorUnknown);Assert.Equal(0,result.Members.Sum(x=>x.Completed));
        await Assert.ThrowsAsync<NotFoundException>(()=>service.ReadAsync(active.HouseId,active.Users[0],day,day,draft.SeasonId,default));
    }
}
