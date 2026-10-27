using ChoreWars.Application.Services.Supplies;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
namespace UnitTests.Services;
public sealed class SupplyCostSplitterTests
{
 [Fact]public void EqualSharesKeepEveryDongAndHaveStableRounding(){
  var a=Guid.Parse("00000000-0000-0000-0000-000000000001");var b=Guid.Parse("00000000-0000-0000-0000-000000000002");var c=Guid.Parse("00000000-0000-0000-0000-000000000003");
  var shares=SupplyCostSplitter.Split(100,new[]{c,b,a});Assert.Equal(100,shares.Values.Sum());Assert.Equal(34,shares[a]);Assert.Equal(33,shares[b]);Assert.Equal(shares,SupplyCostSplitter.Split(100,new[]{a,c,b}));
 }
 [Fact]public void InvalidMoneyAndRepeatedPeopleAreRejected(){var a=Guid.NewGuid();Assert.Throws<DomainException>(()=>SupplyCostSplitter.Split(10.5m,new[]{a}));Assert.Throws<DomainException>(()=>SupplyCostSplitter.Split(10,new[]{a,a}));}
 [Fact]public void MonthlyRemindersUseVietnamCalendarAndClampShortMonths(){
  var after=new DateTime(2026,1,31,13,0,0,DateTimeKind.Utc);Assert.Equal(new DateTime(2026,2,28,12,0,0,DateTimeKind.Utc),SupplyReminderService.Next(31,19,0,after));
 }
 [Fact]public void RefundsUseExactWeightedRemainders(){var a=Guid.NewGuid();var b=Guid.NewGuid();var o=new SupplyOrder{Total=3,Shares=[new(){UserId=a,Amount=2},new(){UserId=b,Amount=1}]};var amounts=SupplyRefundService.Allocate(o,2);Assert.Equal(2,amounts.Values.Sum());Assert.Equal(1,amounts[a]);Assert.Equal(1,amounts[b]);}
}
