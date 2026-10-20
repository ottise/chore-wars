using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;
using Xunit;

namespace UnitTests.Services;

public class HouseCapacityTests
{
    private readonly Mock<IUnitOfWork> _mockUnitOfWork;
    private readonly Mock<IMapper> _mockMapper;
    private readonly HouseService _service;

    public HouseCapacityTests()
    {
        _mockUnitOfWork = new Mock<IUnitOfWork>();
        _mockMapper = new Mock<IMapper>();

        _mockUnitOfWork.Setup(u => u.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _mockUnitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        _mockUnitOfWork.Setup(u => u.Seasons.GetCurrentSeasonByHouseIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((ChoreSeason?)null);
        _service = new HouseService(_mockUnitOfWork.Object, _mockMapper.Object);
    }

    [Fact]
    public async Task JoinHouseAsync_When6ActiveMembers_ShouldThrowConflictException()
    {
        // Arrange
        var houseId = Guid.NewGuid();
        var inviteCode = "INVITE01";
        var house = new House { Id = houseId, InviteCode = inviteCode };

        var newUserId = Guid.NewGuid();

        var activeMembers = new List<HouseMember>();
        for (int i = 0; i < 6; i++)
        {
            activeMembers.Add(new HouseMember
            {
                Id = Guid.NewGuid(),
                HouseId = houseId,
                UserId = Guid.NewGuid(),
                Status = HouseMemberStatus.ACTIVE
            });
        }

        _mockUnitOfWork.Setup(u => u.Houses.GetByInviteCodeAsync(inviteCode, It.IsAny<CancellationToken>())).ReturnsAsync(house);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseAndUserIdAsync(houseId, newUserId, It.IsAny<CancellationToken>())).ReturnsAsync((HouseMember?)null);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>())).ReturnsAsync(activeMembers);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<ConflictException>(() =>
            _service.JoinHouseAsync(new JoinHouseRequest { InviteCode = inviteCode }, newUserId));

        Assert.Contains("six", ex.Message);
    }

    [Fact]
    public async Task JoinHouseAsync_WhenUnder6ActiveMembers_ShouldAddMemberSuccessfully()
    {
        // Arrange
        var houseId = Guid.NewGuid();
        var inviteCode = "INVITE02";
        var house = new House { Id = houseId, InviteCode = inviteCode };

        var newUserId = Guid.NewGuid();

        var activeMembers = new List<HouseMember>
        {
            new() { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE },
            new() { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE },
            new() { Id = Guid.NewGuid(), HouseId = houseId, UserId = Guid.NewGuid(), Status = HouseMemberStatus.ACTIVE }
        };

        HouseMember? addedMember = null;
        _mockUnitOfWork.Setup(u => u.Houses.GetByInviteCodeAsync(inviteCode, It.IsAny<CancellationToken>())).ReturnsAsync(house);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseAndUserIdAsync(houseId, newUserId, It.IsAny<CancellationToken>())).ReturnsAsync((HouseMember?)null);
        _mockUnitOfWork.Setup(u => u.HouseMembers.GetByHouseIdAsync(houseId, It.IsAny<CancellationToken>())).ReturnsAsync(activeMembers);
        _mockUnitOfWork.Setup(u => u.HouseMembers.AddAsync(It.IsAny<HouseMember>(), It.IsAny<CancellationToken>()))
            .Callback<HouseMember, CancellationToken>((m, _) => addedMember = m)
            .Returns(Task.CompletedTask);

        // Act
        await _service.JoinHouseAsync(new JoinHouseRequest { InviteCode = inviteCode }, newUserId);

        // Assert
        Assert.NotNull(addedMember);
        Assert.Equal(houseId, addedMember.HouseId);
        Assert.Equal(newUserId, addedMember.UserId);
        Assert.Equal(HouseRole.MEMBER, addedMember.Role);
        Assert.Equal(HouseMemberStatus.ACTIVE, addedMember.Status);
        _mockUnitOfWork.Verify(u => u.CommitTransactionAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}
