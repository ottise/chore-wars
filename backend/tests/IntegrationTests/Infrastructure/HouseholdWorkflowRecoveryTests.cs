using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.DTOs.Bounty;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
namespace IntegrationTests.Infrastructure;

public class HouseholdWorkflowRecoveryTests
{
    [PostgresFact]
    public async Task PreviewDoesNotWriteConfirmIsIdempotentAndMemberCannotApply()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f);
        RedistributionResult plan;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IMembershipChoreRedistributor>();
            plan = await service.PreviewAsync(seed.HouseId, seed.SeasonId, seed.Users[1], seed.Users[0], default);
            Assert.Single(plan.Changes);
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); Assert.Equal(seed.Users[0], (await db.ChoreOccurrences.SingleAsync()).AssignedUserId);
            Assert.Empty(await db.Set<ScheduleRedistribution>().ToListAsync());
            await Assert.ThrowsAsync<ForbiddenException>(() => service.PreviewAsync(seed.HouseId, seed.SeasonId, seed.Users[2], seed.Users[1], default));
        }
        var request = new ConfirmRedistributionRequest(seed.Users[1], plan.BaseRevision, plan.ContextHash, Guid.NewGuid());
        for (var retry = 0; retry < 2; retry++)
        {
            await using var scope = f.Services.CreateAsyncScope(); var service = scope.ServiceProvider.GetRequiredService<IMembershipChoreRedistributor>();
            var result = await service.ConfirmAsync(seed.HouseId, seed.SeasonId, request, seed.Users[0], default); Assert.Equal(4, result.Revision);
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); Assert.Single(await db.Set<ScheduleRedistribution>().ToListAsync());
            Assert.Equal(seed.Users[1], (await db.ChoreOccurrences.SingleAsync()).AssignedUserId);
            await Assert.ThrowsAsync<ConflictException>(() => scope.ServiceProvider.GetRequiredService<IMembershipChoreRedistributor>().ConfirmAsync(seed.HouseId, seed.SeasonId, request with { ClientRequestId = Guid.NewGuid() }, seed.Users[0], default));
        }
    }
    [PostgresFact]
    public async Task JoinReviewRebuildsRosterAndEachMemberConfirmsNewRevision()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f, SeasonStatus.REVIEWING); var newcomer = Guid.NewGuid(); string code;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); code = (await db.Houses.SingleAsync()).InviteCode;
            db.Users.Add(new User { Id = newcomer, Email = "new-review@example.test", DisplayName = "New", PasswordHash = "test-only" });
            foreach (var approval in await db.SeasonConfirmations.ToListAsync()) approval.Status = ConfirmationStatus.CONFIRMED;
            await db.SaveChangesAsync();
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var results = await scope.ServiceProvider.GetRequiredService<IHouseService>().JoinHouseAsync(new JoinHouseRequest { InviteCode = code }, newcomer);
            Assert.Single(results); Assert.Equal(1, results[0].MovedCount);
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); Assert.Equal(SeasonStatus.REVIEWING, (await db.Seasons.SingleAsync()).Status);
            var rows = await db.SeasonConfirmations.ToListAsync(); Assert.Equal(4, rows.Count); Assert.All(rows, r => { Assert.Equal(4, r.ScheduleRevision); Assert.Equal(ConfirmationStatus.PENDING, r.Status); });
        }
        foreach (var user in seed.Users.Append(newcomer)) { await using var scope = f.Services.CreateAsyncScope(); await scope.ServiceProvider.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(seed.SeasonId, user, default, 4); }
        await using (var scope = f.Services.CreateAsyncScope()) Assert.Equal(SeasonStatus.ACTIVE, (await scope.ServiceProvider.GetRequiredService<AppDbContext>().Seasons.SingleAsync()).Status);
    }
    [PostgresFact]
    public async Task MemberAddsActiveChoreWithoutDeletingExistingWorkAndRetryDoesNotDuplicate()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f);
        var request = new CreateChoreRequest { Name = "New shared chore", KarmaPoints = 10, ClientRequestId = Guid.NewGuid(), FrequencyType = FrequencyType.DAILY, DeadlineMinutes = 1439 };
        Guid created = Guid.Empty;
        for (var retry = 0; retry < 2; retry++) { await using var scope = f.Services.CreateAsyncScope(); var row = await scope.ServiceProvider.GetRequiredService<IChoreService>().CreateChoreAsync(seed.HouseId, request, seed.Users[1]); if (retry == 0) created = row.Id; else Assert.Equal(created, row.Id); }
        await using var read = f.Services.CreateAsyncScope(); var db = read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.NotNull(await db.ChoreOccurrences.SingleOrDefaultAsync(o => o.Id == seed.OccurrenceId));
        var added = await db.ChoreOccurrences.Where(o => o.ChoreId == created).ToListAsync(); Assert.NotEmpty(added); Assert.All(added, o => { Assert.NotNull(o.AssignedUserId); Assert.True(o.DueDate > DateTime.UtcNow); });
        Assert.Equal(2, await db.Chores.CountAsync()); Assert.Equal(4, (await db.Seasons.SingleAsync()).ScheduleRevision);
    }
    [PostgresFact]
    public async Task BountyClaimCreatesOneCommitmentCompletionMakesSameDebtPayableAndPreservesDeadline()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f); Guid bountyId; DateTime due;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            due = (await scope.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync()).DueDate;
            var service = scope.ServiceProvider.GetRequiredService<IBountyService>();
            var bounty = await service.CreateBountyAsync(seed.HouseId, new CreateBountyRequest { ChoreOccurrenceId = seed.OccurrenceId, Amount = 10000 }, seed.Users[0]); bountyId = bounty.Id;
            Assert.Equal(due, bounty.OccurrenceDueAt); Assert.Equal(due, bounty.ExpiresAt);
            await Assert.ThrowsAsync<ConflictException>(() => service.AcceptBountyAsync(bountyId, seed.Users[0]));
        }
        for (var i = 0; i < 2; i++) { await using var scope = f.Services.CreateAsyncScope(); await scope.ServiceProvider.GetRequiredService<IBountyService>().AcceptBountyAsync(bountyId, seed.Users[1]); }
        Guid debtId;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); var debt = await db.PaymentObligations.SingleAsync(); debtId = debt.Id;
            Assert.Equal(PaymentObligationStatus.AWAITING_COMPLETION, debt.Status);
            Assert.Equal(seed.Users[0], debt.DebtorUserId); Assert.Equal(seed.Users[1], debt.CreditorUserId);
            await Assert.ThrowsAsync<ConflictException>(() => scope.ServiceProvider.GetRequiredService<IBountyService>().SettlePaymentAsync(debtId, seed.Users[1]));
        }
        for (var i = 0; i < 2; i++) { await using var scope = f.Services.CreateAsyncScope(); await scope.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(seed.OccurrenceId, null, seed.Users[1]); }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); var debt = await db.PaymentObligations.SingleAsync(); Assert.Equal(debtId, debt.Id); Assert.Equal(PaymentObligationStatus.PENDING, debt.Status);
            Assert.Equal(due, (await db.ChoreOccurrences.SingleAsync()).DueDate); Assert.Single(await db.KarmaTransactions.ToListAsync());
        }
    }
    [PostgresFact]
    public async Task ClaimedBountyCancellationRequiresBothParticipantsAndCancelsOnlyUnfinishedCommitment()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f); Guid bountyId;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IBountyService>();
            bountyId = (await service.CreateBountyAsync(seed.HouseId, new CreateBountyRequest { ChoreOccurrenceId = seed.OccurrenceId, Amount = 10000 }, seed.Users[0])).Id;
            await service.AcceptBountyAsync(bountyId, seed.Users[1]);
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IBountyService>();
            await Assert.ThrowsAsync<ForbiddenException>(() => service.CancelBountyAsync(seed.HouseId, bountyId, seed.Users[2]));
            await service.CancelBountyAsync(seed.HouseId, bountyId, seed.Users[0]);
            await service.CancelBountyAsync(seed.HouseId, bountyId, seed.Users[0]);
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); Assert.Equal(BountyStatus.CLAIMED, (await db.ChoreBounties.SingleAsync()).Status); Assert.Equal(seed.Users[1], (await db.ChoreOccurrences.SingleAsync()).AssignedUserId);
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IBountyService>();
            await service.CancelBountyAsync(seed.HouseId, bountyId, seed.Users[1]);
            await service.CancelBountyAsync(seed.HouseId, bountyId, seed.Users[1]);
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); Assert.Equal(BountyStatus.CANCELLED, (await db.ChoreBounties.SingleAsync()).Status); Assert.Equal(seed.Users[0], (await db.ChoreOccurrences.SingleAsync()).AssignedUserId); Assert.Equal(PaymentObligationStatus.CANCELLED, (await db.PaymentObligations.SingleAsync()).Status);
            await Assert.ThrowsAsync<ConflictException>(() => service.AcceptBountyAsync(bountyId, seed.Users[2]));
        }
    }

    [PostgresFact]
    public async Task FutureDraftDoesNotHideActiveSeasonDuringJoin()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f); var newcomer = Guid.NewGuid(); string code;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); code = (await db.Houses.SingleAsync()).InviteCode;
            db.Users.Add(new User { Id = newcomer, Email = "shadow-draft@example.test", DisplayName = "New", PasswordHash = "test-only" });
            db.Seasons.Add(new ChoreSeason { Id = Guid.NewGuid(), HouseId = seed.HouseId, Name = "Next draft", Status = SeasonStatus.DRAFT, StartDate = DateTime.UtcNow.AddDays(8), EndDate = DateTime.UtcNow.AddDays(10) }); await db.SaveChangesAsync();
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var result = await scope.ServiceProvider.GetRequiredService<IHouseService>().JoinHouseAsync(new JoinHouseRequest { InviteCode = code }, newcomer);
            Assert.Equal(2, result.Count); Assert.Equal(1, result.Single(r => r.SeasonId == seed.SeasonId).AssignedCount);
            Assert.Equal(seed.SeasonId, (await scope.ServiceProvider.GetRequiredService<ISeasonService>().GetActiveSeasonAsync(seed.HouseId, newcomer))!.Id);
        }
    }
    [PostgresFact]
    public async Task CapacityBlockedChoreReportsUnassignedAndOwnerCanResolveAfterUpdatingCapacity()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f);
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Set<MemberConstraint>().AddRange(seed.Users.Select(user => new MemberConstraint { Id = Guid.NewGuid(), HouseId = seed.HouseId, UserId = user, MaxChoresPerWeek = 0, MaxEffortMinutesPerDay = 0 })); await db.SaveChangesAsync();
        }
        Guid occurrence;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var result = await scope.ServiceProvider.GetRequiredService<IChoreService>().CreateChoreAsync(seed.HouseId, new CreateChoreRequest { Name = "Capacity blocked", Type = ChoreType.NORMAL, FrequencyType = FrequencyType.DAILY, KarmaPoints = 10 }, seed.Users[1]);
            Assert.True(result.UnassignedCount > 0); Assert.Equal(0, result.AssignedCount); occurrence = result.OccurrenceIds.First();
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); var limit = await db.Set<MemberConstraint>().SingleAsync(c => c.UserId == seed.Users[1]); limit.MaxChoresPerWeek = 20; limit.MaxEffortMinutesPerDay = 240; await db.SaveChangesAsync();
            await scope.ServiceProvider.GetRequiredService<IChoreAllocationService>().ManualAllocateAsync(seed.SeasonId, occurrence, seed.Users[1], seed.Users[0]);
        }
        await using (var scope = f.Services.CreateAsyncScope()) Assert.Equal(seed.Users[1], (await scope.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync(o => o.Id == occurrence)).AssignedUserId);
    }

    [PostgresFact]
    public async Task LegacyRecoveryAddsOnlyMissingUnfinishedCommitmentAndIsIdempotent() {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();var occurrence=await db.ChoreOccurrences.SingleAsync();occurrence.AssignedUserId=seed.Users[1];
            db.ChoreBounties.Add(new ChoreBounty {Id=Guid.NewGuid(),ChoreOccurrenceId=occurrence.Id,PostedByUserId=seed.Users[0],Status=BountyStatus.CLAIMED,Amount=12000,CreatedAt=DateTime.UtcNow,ExpiresAt=occurrence.DueDate});await db.SaveChangesAsync();
        }
        var recovery=new ChoreWars.Infrastructure.Repositories.LegacyBountyRecovery(f.Services.GetRequiredService<IServiceScopeFactory>(),TimeProvider.System,Microsoft.Extensions.Logging.Abstractions.NullLogger<ChoreWars.Infrastructure.Repositories.LegacyBountyRecovery>.Instance);
        await recovery.StartAsync(default);await recovery.StartAsync(default);
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();var debt=await db.PaymentObligations.SingleAsync();Assert.Equal(PaymentObligationStatus.AWAITING_COMPLETION,debt.Status);Assert.Equal(12000,debt.Amount);Assert.Equal(seed.Users[1],(await db.ChoreBounties.SingleAsync()).ClaimedByUserId);
        }
    }

    [PostgresFact]
    public async Task AddingCapacityBlockedChoreDuringReviewReturnsDraftInsteadOfActivatingIncompleteSchedule() {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f,SeasonStatus.REVIEWING);
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();db.Set<MemberConstraint>().AddRange(seed.Users.Select(user=>new MemberConstraint {Id=Guid.NewGuid(),HouseId=seed.HouseId,UserId=user,MaxChoresPerWeek=0,MaxEffortMinutesPerDay=0}));await db.SaveChangesAsync();
            var result=await scope.ServiceProvider.GetRequiredService<IChoreService>().CreateChoreAsync(seed.HouseId,new CreateChoreRequest {Name="Needs assignment",FrequencyType=FrequencyType.DAILY,KarmaPoints=10},seed.Users[1]);Assert.True(result.UnassignedCount>0);
        }
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();var season=await db.Seasons.SingleAsync();Assert.Equal(SeasonStatus.DRAFT,season.Status);Assert.Equal(4,season.ScheduleRevision);Assert.Empty(await db.SeasonConfirmations.ToListAsync());
        }
    }

    [PostgresFact]
    public async Task ChatCursorCountsMessagesNotNotificationsAndNeverMovesBackwards()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f); Guid first, last;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); var room = new ChatRoom { Id = Guid.NewGuid(), HouseId = seed.HouseId, Name = "Chat", CreatedAt = DateTime.UtcNow }; db.ChatRooms.Add(room);
            var at = DateTime.UtcNow.AddMinutes(1); var messages = Enumerable.Range(0, 11).Select(i => new ChatMessage { Id = Guid.NewGuid(), RoomId = room.Id, SenderId = seed.Users[0], Content = "Test " + i, CreatedAt = at.AddSeconds(i) }).ToList();
            first = messages[0].Id; last = messages[^1].Id; db.ChatMessages.AddRange(messages); await db.SaveChangesAsync();
        }
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var reads = scope.ServiceProvider.GetRequiredService<IChatReadService>(); Assert.Equal(11, await reads.UnreadAsync(seed.HouseId, seed.Users[1], default)); Assert.Equal(0, await reads.UnreadAsync(seed.HouseId, seed.Users[0], default));
            await reads.ReadAsync(seed.HouseId, seed.Users[1], last, default); await reads.ReadAsync(seed.HouseId, seed.Users[1], first, default); Assert.Equal(0, await reads.UnreadAsync(seed.HouseId, seed.Users[1], default));
            await Assert.ThrowsAsync<ForbiddenException>(() => reads.UnreadAsync(seed.HouseId, Guid.NewGuid(), default));
        }
    }
}
