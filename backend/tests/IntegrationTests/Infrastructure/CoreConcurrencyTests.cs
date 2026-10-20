using ChoreWars.Application.DTOs.Gamification;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
namespace IntegrationTests.Infrastructure;
public class CoreConcurrencyTests {
    internal sealed record Data(Guid HouseId,Guid SeasonId,Guid OccurrenceId,Guid[] Users);
    internal static async Task<Data> Seed(PostgresFixture fixture,SeasonStatus status=SeasonStatus.ACTIVE) {
        await using var scope=fixture.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var users=Enumerable.Range(0,3).Select(i=>new User {Id=Guid.NewGuid(),Email=Guid.NewGuid()+"@example.test",DisplayName="Member "+i,PasswordHash="test-only",CreatedAt=DateTime.UtcNow}).ToArray();
        db.Users.AddRange(users);
        var house=new House{Id=Guid.NewGuid(),Name="Test house",InviteCode=Guid.NewGuid().ToString("N")[..10],CreatedAt=DateTime.UtcNow};db.Houses.Add(house);
        db.HouseMembers.AddRange(users.Select((u,i)=>new HouseMember{Id=Guid.NewGuid(),HouseId=house.Id,UserId=u.Id,Status=HouseMemberStatus.ACTIVE,Role=i==0?HouseRole.OWNER:HouseRole.MEMBER,JoinedAt=DateTime.UtcNow,KarmaBalance=50}));
        var season=new ChoreSeason{Id=Guid.NewGuid(),HouseId=house.Id,Name="Test season",StartDate=DateTime.UtcNow.AddDays(-1),EndDate=DateTime.UtcNow.AddDays(5),Status=status,ScheduleRevision=3};db.Seasons.Add(season);
        db.SeasonConfirmations.AddRange(users.Select(u=>new SeasonConfirmation{Id=Guid.NewGuid(),SeasonId=season.Id,UserId=u.Id,ScheduleRevision=3,Status=ConfirmationStatus.PENDING,CreatedAt=DateTime.UtcNow,UpdatedAt=DateTime.UtcNow}));
        var chore=new Chore{Id=Guid.NewGuid(),HouseId=house.Id,SeasonId=season.Id,Name="Dishes",Type=ChoreType.NORMAL,KarmaPoints=10};db.Chores.Add(chore);
        var occurrence=new ChoreOccurrence{Id=Guid.NewGuid(),ChoreId=chore.Id,SeasonId=season.Id,AssignedUserId=users[0].Id,Status=ChoreOccurrenceStatus.ASSIGNED,DueDate=DateTime.UtcNow.AddHours(1),SnapshotKarma=10,SnapshotMinutes=30};db.ChoreOccurrences.Add(occurrence);
        await db.SaveChangesAsync();return new(house.Id,season.Id,occurrence.Id,users.Select(u=>u.Id).ToArray());
    }
    private static async Task<bool> Run(Func<Task> action) {try {await action();return true;}catch(ConflictException){return false;}}
    [PostgresFact] public async Task CompetingCompletionsCreditKarmaAndOutboxOnce() {
        await using var f=await PostgresFixture.CreateAsync();var seed=await Seed(f);
        async Task<bool> Complete(){await using var scope=f.Services.CreateAsyncScope();return await Run(()=>scope.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(seed.OccurrenceId,null,seed.Users[0]));}
        var results=await Task.WhenAll(Complete(),Complete());Assert.All(results,x=>Assert.True(x));
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Single(await db.KarmaTransactions.Where(x=>x.ReferenceId==seed.OccurrenceId).ToListAsync());
        Assert.Single(await db.OutboxMessages.ToListAsync());
        Assert.Equal(60,(await db.HouseMembers.SingleAsync(x=>x.HouseId==seed.HouseId&&x.UserId==seed.Users[0])).KarmaBalance);
    }
    [PostgresFact] public async Task SimultaneousConfirmationsActivateOnlyAfterAllThreePersist() {
        await using var f=await PostgresFixture.CreateAsync();var seed=await Seed(f,SeasonStatus.REVIEWING);
        await Task.WhenAll(seed.Users.Select(async user=>{await using var scope=f.Services.CreateAsyncScope();await scope.ServiceProvider.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(seed.SeasonId,user,expectedRevision:3);}));
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(SeasonStatus.ACTIVE,(await db.Seasons.SingleAsync()).Status);
        Assert.Equal(3,await db.SeasonConfirmations.CountAsync(x=>x.Status==ConfirmationStatus.CONFIRMED));
    }
    [PostgresFact] public async Task ConcurrentRewardRedemptionsCannotOverspend() {
        await using var f=await PostgresFixture.CreateAsync();var seed=await Seed(f);
        Guid reward;
        await using(var create=f.Services.CreateAsyncScope())reward=(await create.ServiceProvider.GetRequiredService<IRewardService>().CreateAsync(seed.HouseId,new CreateRewardRequest("Movie choice","Choose the movie",40),seed.Users[0],default)).Id;
        async Task<bool> Redeem(){await using var scope=f.Services.CreateAsyncScope();return await Run(()=>scope.ServiceProvider.GetRequiredService<IRewardService>().RedeemAsync(seed.HouseId,reward,Guid.NewGuid(),seed.Users[0],default));}
        var results=await Task.WhenAll(Redeem(),Redeem());Assert.Single(results,x=>x);
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(10,(await db.HouseMembers.SingleAsync(x=>x.UserId==seed.Users[0])).KarmaBalance);
        Assert.Single(await db.RewardRedemptions.ToListAsync());
    }
    [PostgresFact] public async Task PaymentReceiptRetryDoesNotChangeAuditTime() {
        await using var f=await PostgresFixture.CreateAsync();var seed=await Seed(f);var paymentId=Guid.NewGuid();
        await using(var create=f.Services.CreateAsyncScope()){var seedDb=create.ServiceProvider.GetRequiredService<AppDbContext>();seedDb.PaymentObligations.Add(new PaymentObligation{Id=paymentId,HouseId=seed.HouseId,SeasonId=seed.SeasonId,DebtorUserId=seed.Users[0],CreditorUserId=seed.Users[1],Amount=30000,Status=PaymentObligationStatus.PENDING,Reason=PaymentObligationReason.OTHER,CreatedAt=DateTime.UtcNow});await seedDb.SaveChangesAsync();}
        async Task Confirm(){await using var scope=f.Services.CreateAsyncScope();await scope.ServiceProvider.GetRequiredService<IBountyService>().SettlePaymentAsync(paymentId,seed.Users[1]);}
        await Task.WhenAll(Confirm(),Confirm());
        DateTime? firstPaidAt;
        await using(var audit=f.Services.CreateAsyncScope()) firstPaidAt=(await audit.ServiceProvider.GetRequiredService<AppDbContext>().PaymentObligations.SingleAsync()).PaidAt;
        await Confirm();
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();var payment=await db.PaymentObligations.SingleAsync();
        Assert.Equal(PaymentObligationStatus.PAID,payment.Status);Assert.Equal(seed.Users[1],payment.ConfirmedByUserId);Assert.NotNull(payment.PaidAt);Assert.Equal(firstPaidAt,payment.PaidAt);
    }
}
