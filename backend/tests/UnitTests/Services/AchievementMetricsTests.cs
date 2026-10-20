using AutoMapper;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;
using Moq;
namespace UnitTests.Services;
public class AchievementMetricsTests
{
    private static (Mock<IUnitOfWork> Uow,AchievementCheckService Service,Guid House,Guid User,List<UserAchievement> Awards) Fixture(AchievementConditionType kind,int threshold) {
        var house=Guid.NewGuid();var user=Guid.NewGuid();var awards=new List<UserAchievement>();var uow=new Mock<IUnitOfWork>();
        uow.Setup(x=>x.HouseMembers.GetByHouseAndUserIdAsync(house,user,It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember{UserId=user,Status=HouseMemberStatus.ACTIVE});
        uow.Setup(x=>x.Achievements.GetByHouseIdAsync(house,It.IsAny<CancellationToken>())).ReturnsAsync(new[]{new Achievement{Id=Guid.NewGuid(),HouseId=house,ConditionType=kind,Threshold=threshold}});
        uow.Setup(x=>x.UserAchievements.GetByUserIdAsync(user,It.IsAny<CancellationToken>())).ReturnsAsync(awards);
        uow.Setup(x=>x.UserAchievements.AddAsync(It.IsAny<UserAchievement>(),It.IsAny<CancellationToken>())).Callback<UserAchievement,CancellationToken>((item,_)=>awards.Add(item)).Returns(Task.CompletedTask);
        return(uow,new(uow.Object,Mock.Of<ILogger<AchievementCheckService>>()),house,user,awards);
    }
    [Fact] public async Task KarmaAchievementUsesOnlyEarnedPointsInThisHouseAndAwardsOnce() {
        var f=Fixture(AchievementConditionType.KARMA_EARNED,100);
        var earned=new KarmaTransaction{HouseId=f.House,Amount=50,Type=KarmaTransactionType.CHORE_COMPLETED};
        f.Uow.Setup(x=>x.KarmaTransactions.GetByUserIdAsync(f.User,It.IsAny<CancellationToken>())).ReturnsAsync(new[]{earned,new KarmaTransaction{HouseId=Guid.NewGuid(),Amount=999,Type=KarmaTransactionType.BONUS},new KarmaTransaction{HouseId=f.House,Amount=999,Type=KarmaTransactionType.REWARD_REDEEMED}});
        await f.Service.CheckAchievementsAsync(f.House,f.User,AchievementConditionType.KARMA_EARNED);Assert.Empty(f.Awards);
        earned.Amount=100;await f.Service.CheckAchievementsAsync(f.House,f.User,AchievementConditionType.KARMA_EARNED);await f.Service.CheckAchievementsAsync(f.House,f.User,AchievementConditionType.KARMA_EARNED);Assert.Single(f.Awards);
    }
    [Fact] public void StreakCountsDistinctConsecutiveCalendarDaysAcrossMonthBoundary() {
        Assert.Equal(3,AchievementCheckService.LongestStreak([new(2026,2,27),new(2026,2,28),new(2026,2,28),new(2026,3,1),new(2026,3,5)]));
    }
    [Fact] public async Task CompletionAchievementCannotUseAnotherHouse() {
        var f=Fixture(AchievementConditionType.CHORES_COMPLETED,1);
        f.Uow.Setup(x=>x.ChoreOccurrences.GetByAssignedUserIdAsync(f.User,It.IsAny<CancellationToken>())).ReturnsAsync(new[]{new ChoreOccurrence{Chore=new Chore{HouseId=Guid.NewGuid()},AssignedUserId=f.User,CompletedByUserId=f.User,Status=ChoreOccurrenceStatus.COMPLETED}});
        await f.Service.CheckAchievementsAsync(f.House,f.User,AchievementConditionType.CHORES_COMPLETED);Assert.Empty(f.Awards);
    }
    [Fact] public async Task AcceptedBountyUsesResponsibilityHistoryRatherThanCurrentAssignment() {
        var f=Fixture(AchievementConditionType.BOUNTIES_CLAIMED,1);
        f.Uow.Setup(x=>x.ChoreOccurrences.CountAcceptedBountiesAsync(f.House,f.User,It.IsAny<CancellationToken>())).ReturnsAsync(1);
        await f.Service.CheckAchievementsAsync(f.House,f.User,AchievementConditionType.BOUNTIES_CLAIMED);Assert.Single(f.Awards);
    }
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task SpendableBalanceDoesNotResetAtSeasonBoundary(bool activeSeason) {
        var house=Guid.NewGuid();var user=Guid.NewGuid();var uow=new Mock<IUnitOfWork>();
        uow.Setup(x=>x.HouseMembers.GetByHouseAndUserIdAsync(house,user,It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember{Status=HouseMemberStatus.ACTIVE,KarmaBalance=37});
        var season=new ChoreSeason{Id=Guid.NewGuid(),HouseId=house,Status=SeasonStatus.ACTIVE};
        uow.Setup(x=>x.Seasons.GetActiveSeasonByHouseIdAsync(house,It.IsAny<CancellationToken>())).ReturnsAsync(activeSeason?season:null);
        uow.Setup(x=>x.KarmaTransactions.GetByUserIdAsync(user,It.IsAny<CancellationToken>())).ReturnsAsync(new[]{new KarmaTransaction{HouseId=house,SeasonId=season.Id,Amount=100,Type=KarmaTransactionType.CHORE_COMPLETED}});
        var service=new GamificationService(uow.Object,Mock.Of<IMapper>());
        Assert.Equal(37,await service.GetKarmaBalanceAsync(house,user));
    }
}
