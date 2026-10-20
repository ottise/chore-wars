using AutoMapper;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;
public class ChorePassMembershipTests
{
    [Theory]
    [InlineData(HouseMemberStatus.LEFT)]
    [InlineData(HouseMemberStatus.BANNED)]
    public async Task FormerMemberCannotClaimAnAwardedPass(HouseMemberStatus status)
    {
        var reward=new Reward {Id=Guid.NewGuid(),HouseId=Guid.NewGuid(),Type=RewardType.CHORE_PASS};
        var redemption=new RewardRedemption {Id=Guid.NewGuid(),RewardId=reward.Id,UserId=Guid.NewGuid(),Status=RewardRedemptionStatus.UNCLAIMED,ClaimDeadline=DateTime.UtcNow.AddDays(1)};
        var uow=new Mock<IUnitOfWork>();
        uow.Setup(x=>x.RewardRedemptions.GetByIdAsync(redemption.Id,It.IsAny<CancellationToken>())).ReturnsAsync(redemption);
        uow.Setup(x=>x.Rewards.GetByIdAsync(reward.Id,It.IsAny<CancellationToken>())).ReturnsAsync(reward);
        uow.Setup(x=>x.HouseMembers.GetByHouseAndUserIdAsync(reward.HouseId,redemption.UserId,It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember{UserId=redemption.UserId,Status=status});
        var service=new GamificationService(uow.Object,Mock.Of<IMapper>());
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.ClaimRewardAsync(redemption.Id,redemption.UserId));
        Assert.Equal(RewardRedemptionStatus.UNCLAIMED,redemption.Status);
        uow.Verify(x=>x.RewardRedemptions.Update(It.IsAny<RewardRedemption>()),Times.Never);
    }
}
