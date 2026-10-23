using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public sealed class ChatNotificationSettingsTests
{
    [Fact]
    public async Task PreferenceIsEnabledByDefaultAndCanBeMutedAndEnabled()
    {
        var member = new HouseMember { HouseId = Guid.NewGuid(), UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE };
        var members = new Mock<IHouseMemberRepository>();
        members.Setup(x => x.GetByHouseAndUserIdAsync(member.HouseId, member.UserId, It.IsAny<CancellationToken>())).ReturnsAsync(member);
        var uow = new Mock<IUnitOfWork>();
        uow.SetupGet(x => x.HouseMembers).Returns(members.Object);
        var service = new ChatService(uow.Object);
        Assert.True(await service.GetNotificationsEnabledAsync(member.HouseId, member.UserId));
        await service.SetNotificationsEnabledAsync(member.HouseId, member.UserId, false);
        Assert.False(await service.GetNotificationsEnabledAsync(member.HouseId, member.UserId));
        await service.SetNotificationsEnabledAsync(member.HouseId, member.UserId, true);
        Assert.True(await service.GetNotificationsEnabledAsync(member.HouseId, member.UserId));
        members.Verify(x => x.Update(member), Times.Exactly(2));
        uow.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    [Theory]
    [InlineData(HouseMemberStatus.LEFT)]
    [InlineData(HouseMemberStatus.BANNED)]
    [InlineData(HouseMemberStatus.PENDING)]
    public async Task InactiveMembersCannotReadOrChangeNotificationSettings(HouseMemberStatus status)
    {
        var member = new HouseMember { HouseId = Guid.NewGuid(), UserId = Guid.NewGuid(), Status = status };
        var members = new Mock<IHouseMemberRepository>();
        members.Setup(x => x.GetByHouseAndUserIdAsync(member.HouseId, member.UserId, It.IsAny<CancellationToken>())).ReturnsAsync(member);
        var uow = new Mock<IUnitOfWork>();
        uow.SetupGet(x => x.HouseMembers).Returns(members.Object);
        var service = new ChatService(uow.Object);
        await Assert.ThrowsAsync<ForbiddenException>(() => service.GetNotificationsEnabledAsync(member.HouseId, member.UserId));
        await Assert.ThrowsAsync<ForbiddenException>(() => service.SetNotificationsEnabledAsync(member.HouseId, member.UserId, false));
        uow.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
