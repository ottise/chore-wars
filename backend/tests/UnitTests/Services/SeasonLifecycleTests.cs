using AutoMapper;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;
namespace UnitTests.Services;
public class SeasonLifecycleTests {
    private static (SeasonService Service,ChoreSeason Season,List<SeasonConfirmation> Confirmations,List<HouseMember> Members) Setup() {
        var season=new ChoreSeason{Id=Guid.NewGuid(),HouseId=Guid.NewGuid(),Status=SeasonStatus.REVIEWING,ScheduleRevision=7};
        var members=Enumerable.Range(0,3).Select(_=>new HouseMember{UserId=Guid.NewGuid(),Status=HouseMemberStatus.ACTIVE}).ToList();
        var confirmations=members.Select(m=>new SeasonConfirmation{UserId=m.UserId,SeasonId=season.Id,ScheduleRevision=7,Status=ConfirmationStatus.PENDING}).ToList();
        var uow=new Mock<IUnitOfWork>();
        uow.Setup(x=>x.Seasons.GetByIdAsync(season.Id,It.IsAny<CancellationToken>())).ReturnsAsync(season);
        uow.Setup(x=>x.HouseMembers.GetByHouseIdAsync(season.HouseId,It.IsAny<CancellationToken>())).ReturnsAsync(members);
        uow.Setup(x=>x.SeasonConfirmations.GetBySeasonIdAsync(season.Id,It.IsAny<CancellationToken>())).ReturnsAsync(confirmations);
        foreach(var c in confirmations) uow.Setup(x=>x.SeasonConfirmations.GetBySeasonAndUserIdAsync(season.Id,c.UserId,It.IsAny<CancellationToken>())).ReturnsAsync(c);
        return(new(uow.Object,Mock.Of<IMapper>(),Mock.Of<IChoreGenerationService>(),Mock.Of<IChoreAllocationService>()),season,confirmations,members);
    }
    [Fact] public async Task FirstConfirmationDoesNotActivateSeason() {
        var f=Setup();await f.Service.ConfirmSeasonAsync(f.Season.Id,f.Members[0].UserId,expectedRevision:7);
        Assert.Equal(SeasonStatus.REVIEWING,f.Season.Status);
    }
    [Fact] public async Task OnlyLastRequiredConfirmationActivatesSeason() {
        var f=Setup();foreach(var member in f.Members) await f.Service.ConfirmSeasonAsync(f.Season.Id,member.UserId,expectedRevision:7);
        Assert.Equal(SeasonStatus.ACTIVE,f.Season.Status);
    }
    [Fact] public async Task StaleRevisionCannotBeApproved() {
        var f=Setup();await Assert.ThrowsAsync<ConflictException>(()=>f.Service.ConfirmSeasonAsync(f.Season.Id,f.Members[0].UserId,expectedRevision:6));
        Assert.All(f.Confirmations,c=>Assert.Equal(ConfirmationStatus.PENDING,c.Status));
    }
    [Fact] public async Task MembershipChangesInvalidateOldConfirmations() {
        var f=Setup();f.Members.Add(new HouseMember{UserId=Guid.NewGuid(),Status=HouseMemberStatus.ACTIVE});
        await Assert.ThrowsAsync<ConflictException>(()=>f.Service.ConfirmSeasonAsync(f.Season.Id,f.Members[0].UserId,expectedRevision:7));
    }
    [Fact] public async Task LegacyStartCannotBypassReview() {
        var f=Setup();f.Season.Status=SeasonStatus.DRAFT;
        await Assert.ThrowsAsync<ConflictException>(()=>f.Service.StartSeasonAsync(f.Season.Id,f.Members[0].UserId));
    }
}
