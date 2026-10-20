using ChoreWars.Application.DTOs.Gamification;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public class RewardEligibilityTests
{
    private sealed class InlineMutations : IHouseMutationCoordinator
    {
        public Task RunAsync(Guid houseId, Func<Task> action, CancellationToken ct = default) => action();
        public Task<T> RunAsync<T>(Guid houseId, Func<Task<T>> action, CancellationToken ct = default) => action();
    }

    private static (RewardService Service, Mock<IUnitOfWork> Uow, Reward Reward, HouseMember Member) Setup()
    {
        var house = Guid.NewGuid();
        var user = Guid.NewGuid();
        var reward = new Reward { Id = Guid.NewGuid(), HouseId = house, Name = "Movie", Cost = 40, Enabled = true, Type = RewardType.CUSTOM };
        var member = new HouseMember { UserId = user, HouseId = house, Status = HouseMemberStatus.ACTIVE, KarmaBalance = 50 };
        var uow = new Mock<IUnitOfWork>();
        uow.Setup(x => x.HouseMembers.GetByHouseAndUserIdAsync(house,user,It.IsAny<CancellationToken>())).ReturnsAsync(member);
        uow.Setup(x => x.Rewards.GetByIdAsync(reward.Id,It.IsAny<CancellationToken>())).ReturnsAsync(reward);
        uow.Setup(x => x.RewardRedemptions.GetByRequestAsync(reward.Id,user,It.IsAny<Guid>(),It.IsAny<CancellationToken>())).ReturnsAsync((RewardRedemption?)null);
        return (new RewardService(uow.Object,new InlineMutations()),uow,reward,member);
    }

    [Fact] public async Task DisabledRewardCannotDebitBalance()
    {
        var f = Setup(); f.Reward.Enabled = false;
        await Assert.ThrowsAsync<ConflictException>(() => f.Service.RedeemAsync(f.Member.HouseId,f.Reward.Id,Guid.NewGuid(),f.Member.UserId,default));
        Assert.Equal(50,f.Member.KarmaBalance);
        f.Uow.Verify(x => x.RewardRedemptions.AddAsync(It.IsAny<RewardRedemption>(),It.IsAny<CancellationToken>()),Times.Never);
    }

    [Fact] public async Task UpdateCannotChangeAnAwardedChorePass()
    {
        var f = Setup(); f.Reward.Type = RewardType.CHORE_PASS;
        await Assert.ThrowsAsync<NotFoundException>(() => f.Service.UpdateAsync(f.Member.HouseId,f.Reward.Id,new UpdateRewardRequest("Pass","",1,false),f.Member.UserId,default));
        Assert.True(f.Reward.Enabled);
    }

    [Fact] public async Task CustomRewardCanBeDisabledWithoutDeletingHistory()
    {
        var f = Setup();
        var result = await f.Service.UpdateAsync(f.Member.HouseId,f.Reward.Id,new UpdateRewardRequest("Movie night","Choose movie",60,false),f.Member.UserId,default);
        Assert.False(result.Enabled); Assert.Equal(60,result.Cost);
        Assert.Equal(50,f.Member.KarmaBalance);
        f.Uow.Verify(x => x.Rewards.Delete(It.IsAny<Reward>()),Times.Never);
    }

    [Fact] public async Task CrossHouseRewardCannotBeEdited()
    {
        var f = Setup(); f.Reward.HouseId = Guid.NewGuid();
        await Assert.ThrowsAsync<NotFoundException>(() => f.Service.UpdateAsync(f.Member.HouseId,f.Reward.Id,new UpdateRewardRequest("Movie","",20,true),f.Member.UserId,default));
    }
}
