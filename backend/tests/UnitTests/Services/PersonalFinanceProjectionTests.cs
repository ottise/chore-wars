using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace UnitTests.Services;
public sealed class PersonalFinanceProjectionTests
{
    [Fact] public void LegacyPaidDebtHasNoRemainingBalanceWithoutInventingTransferRows()
    {
        var d=new PaymentObligation{Id=Guid.NewGuid(),Amount=100,Status=PaymentObligationStatus.PAID,Reason=PaymentObligationReason.BOUNTY_PAYMENT,DebtorUser=new(){DisplayName="A"},CreditorUser=new(){DisplayName="B"}};
        var row=PersonalFinanceService.Debt(d,new([d],[],[]));Assert.Equal(0,row.RemainingAmount);Assert.Equal(100,row.ConfirmedAmount);Assert.Null(row.SourceOrderId);Assert.Empty(row.Repayments);
    }
    [Fact] public void PendingReportsDoNotReduceTheDebtAndRejectedReportsDoNotCount()
    {
        var d=new PaymentObligation{Id=Guid.NewGuid(),Amount=100,DebtorUser=new(){DisplayName="A"},CreditorUser=new(){DisplayName="B"}};
        var row=PersonalFinanceService.Debt(d,new([d],[new(){ObligationId=d.Id,Amount=40,Status=InternalRepaymentStatus.CONFIRMED},new(){ObligationId=d.Id,Amount=60,Status=InternalRepaymentStatus.REPORTED},new(){ObligationId=d.Id,Amount=60,Status=InternalRepaymentStatus.REJECTED}],[]));
        Assert.Equal(40,row.ConfirmedAmount);Assert.Equal(60,row.RemainingAmount);
    }
    [Fact] public void DateRangesUseVietnamMidnightAndRejectUnboundedQueries()
    {
        var date=new DateOnly(2026,10,28);var range=PersonalFinanceService.Range(date,date);
        Assert.Equal(new DateTime(2026,10,27,17,0,0,DateTimeKind.Utc),range.From);Assert.Equal(TimeSpan.FromDays(1),range.To-range.From);
        Assert.Throws<DomainException>(()=>PersonalFinanceService.Range(date,date.AddDays(-1)));
        Assert.Throws<DomainException>(()=>PersonalFinanceService.Range(date,date.AddDays(367)));
    }
}
