using ChoreWars.Application.DTOs.Bounty;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.DTOs.Gamification;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public sealed class PostgresTheoryAttribute : TheoryAttribute
{
    public PostgresTheoryAttribute() { if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_POSTGRES"))) Skip = "Requires disposable PostgreSQL."; }
}
public class HouseholdJourneyTests
{
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now = new(2026, 10, 20, 1, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }
    [PostgresTheory]
    [InlineData(3, AllocationMethod.AUTOMATIC)]
    [InlineData(6, AllocationMethod.MANUAL)]
    public async Task HouseholdJourneyPreservesReviewPaymentsSeasonLedgerAndPass(int count, AllocationMethod method)
    {
        var clock = new Clock();
        await using var fixture = await PostgresFixture.CreateAsync(configure: s => s.AddSingleton<TimeProvider>(clock));
        async Task<T> Run<T>(Func<IServiceProvider, Task<T>> action) { await using var scope = fixture.Services.CreateAsyncScope(); return await action(scope.ServiceProvider); }
        async Task Act(Func<IServiceProvider, Task> action) { await using var scope = fixture.Services.CreateAsyncScope(); await action(scope.ServiceProvider); }
        var users = Enumerable.Range(0, count + 1).Select(i => new User { Id = Guid.NewGuid(), Email = Guid.NewGuid() + "@example.test", DisplayName = "Journey " + i, PasswordHash = "fixture-only", CreatedAt = clock.Now.UtcDateTime }).ToArray();
        await Act(async s => { var db = s.GetRequiredService<AppDbContext>(); db.Users.AddRange(users); await db.SaveChangesAsync(); });
        var owner = users[0].Id;
        var house = await Run(s => s.GetRequiredService<IHouseService>().CreateHouseAsync(new CreateHouseRequest { Name = "Journey household" }, owner));
        foreach (var user in users.Skip(1).Take(count - 1)) await Act(s => s.GetRequiredService<IHouseService>().JoinHouseAsync(new JoinHouseRequest { InviteCode = house.InviteCode }, user.Id));
        if (count == 6) await Assert.ThrowsAsync<ConflictException>(() => Act(s => s.GetRequiredService<IHouseService>().JoinHouseAsync(new JoinHouseRequest { InviteCode = house.InviteCode }, users[^1].Id)));
        var season = await Run(s => s.GetRequiredService<ISeasonService>().CreateSeasonAsync(house.Id, new CreateSeasonRequest { Name = "Journey", StartDate = clock.Now.UtcDateTime, EndDate = clock.Now.AddDays(2).UtcDateTime, AllocationMethod = method }, owner));
        var available = new MemberAvailabilityRequest { Slots = Enumerable.Range(0, 7).ToDictionary(d => d, _ => new List<AvailabilitySlotRequest> { new() { StartMinute = 0, EndMinute = 1440 } }) };
        foreach (var user in users.Take(count)) await Act(s => s.GetRequiredService<ISeasonService>().SetAvailabilityAsync(season.Id, available, user.Id));
        foreach (var effort in new[] { ChoreEffort.EASY, ChoreEffort.MEDIUM, ChoreEffort.HARD })
        {
            var routine = await Run(s => s.GetRequiredService<IChoreService>().CreateChoreAsync(house.Id, new CreateChoreRequest { Name = "Routine " + effort, Description = "Runtime fixture", AsRoutine = true, Type = ChoreType.NORMAL, Difficulty = effort, FrequencyType = FrequencyType.DAILY, KarmaPoints = 10 * (int)effort }, owner));
            await Run(s => s.GetRequiredService<IChoreService>().ImportRoutineAsync(house.Id, season.Id, routine.Id, owner));
        }
        await Run(s => s.GetRequiredService<IChoreService>().CreateChoreAsync(house.Id, new CreateChoreRequest { Name = "Bonus", Type = ChoreType.BONUS, Difficulty = ChoreEffort.EASY, FrequencyType = FrequencyType.DAILY, KarmaPoints = 20 }, owner));
        async Task GenerateAndAssign(Guid id)
        {
            await Act(s => s.GetRequiredService<ISeasonService>().GenerateScheduleAsync(id, owner));
            if (method == AllocationMethod.MANUAL)
            {
                var occurrences = await Run(async s => (await s.GetRequiredService<ISeasonService>().GetOccurrencesAsync(id, owner)).Where(x => x.Type == ChoreType.NORMAL).OrderBy(x => x.DueDate).ThenBy(x => x.Id).ToList());
                for (var index = 0; index < occurrences.Count; index++)
                {
                    var occurrence = occurrences[index]; var assignee = users[index % count].Id;
                    await Act(s => s.GetRequiredService<IChoreAllocationService>().ManualAllocateAsync(id, occurrence.Id, assignee, owner));
                }
            }
        }
        await GenerateAndAssign(season.Id);
        await Act(s => s.GetRequiredService<ISeasonService>().SubmitReviewAsync(season.Id, owner));
        var oldRevision = await Run(async s => (await s.GetRequiredService<AppDbContext>().Seasons.SingleAsync(x => x.Id == season.Id)).ScheduleRevision);
        await Act(s => s.GetRequiredService<ISeasonService>().RejectSeasonAsync(season.Id, users[1].Id, reason: "Adjust the distribution"));
        Assert.Equal(0, await Run(s => s.GetRequiredService<AppDbContext>().ChoreOccurrences.CountAsync(x => x.SeasonId == season.Id)));
        await GenerateAndAssign(season.Id); await Act(s => s.GetRequiredService<ISeasonService>().SubmitReviewAsync(season.Id, owner));
        var revision = await Run(async s => (await s.GetRequiredService<AppDbContext>().Seasons.SingleAsync(x => x.Id == season.Id)).ScheduleRevision);
        await Assert.ThrowsAsync<ConflictException>(() => Act(s => s.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(season.Id, owner, expectedRevision: oldRevision)));
        for (var index = 0; index < count; index++)
        {
            await Act(s => s.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(season.Id, users[index].Id, expectedRevision: revision));
            var status = await Run(async s => (await s.GetRequiredService<AppDbContext>().Seasons.SingleAsync(x => x.Id == season.Id)).Status);
            Assert.Equal(index == count - 1 ? SeasonStatus.ACTIVE : SeasonStatus.REVIEWING, status);
        }
        var all = await Run(async s => (await s.GetRequiredService<ISeasonService>().GetOccurrencesAsync(season.Id, owner)).OrderBy(x => x.DueDate).ThenBy(x => x.Id).ToList());
        var normal = all.Where(x => x.Type == ChoreType.NORMAL).ToList();
        var completed = normal[0];
        await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(completed.Id, null, completed.AssignedUserId!.Value));
        await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(completed.Id, null, completed.AssignedUserId!.Value));
        Assert.Equal(1, await Run(s => s.GetRequiredService<AppDbContext>().KarmaTransactions.CountAsync(x => x.ReferenceId == completed.Id)));
        var help = normal[1]; var debtor = help.AssignedUserId!.Value; var creditor = users.First(u => u.Id != debtor).Id;
        var bounty = await Run(s => s.GetRequiredService<IBountyService>().CreateBountyAsync(house.Id, new CreateBountyRequest { ChoreOccurrenceId = help.Id, Amount = 30000 }, debtor));
        await Act(s => s.GetRequiredService<IBountyService>().AcceptBountyAsync(bounty.Id, creditor));
        await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(help.Id, null, creditor));
        var payment = await Run(s => s.GetRequiredService<AppDbContext>().PaymentObligations.SingleAsync(x => x.OccurrenceId == help.Id));
        await Assert.ThrowsAsync<ForbiddenException>(() => Act(s => s.GetRequiredService<IBountyService>().SettlePaymentAsync(payment.Id, debtor)));
        await Act(s => s.GetRequiredService<IBountyService>().SettlePaymentAsync(payment.Id, creditor));
        var bonus = all.First(x => x.Type == ChoreType.BONUS);
        await Act(s => s.GetRequiredService<IChoreService>().ClaimBonusAsync(bonus.Id, owner));
        await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(bonus.Id, null, owner));
        var reward = await Run(s => s.GetRequiredService<IRewardService>().CreateAsync(house.Id, new CreateRewardRequest("Movie", "Choose movie", 5), owner, default));
        var requestId = Guid.NewGuid();
        await Act(s => s.GetRequiredService<IRewardService>().RedeemAsync(house.Id, reward.Id, requestId, owner, default));
        await Act(s => s.GetRequiredService<IRewardService>().RedeemAsync(house.Id, reward.Id, requestId, owner, default));
        Assert.Equal(1, await Run(s => s.GetRequiredService<AppDbContext>().RewardRedemptions.CountAsync(x => x.RewardId == reward.Id)));
        var forcedOccurrence = normal[2]; var forcedDebtor = forcedOccurrence.AssignedUserId!.Value;
        await Run(s => s.GetRequiredService<IBountyService>().CreateBountyAsync(house.Id, new CreateBountyRequest { ChoreOccurrenceId = forcedOccurrence.Id, Amount = 10000 }, forcedDebtor));
        clock.Now = clock.Now.AddHours(24).AddSeconds(1);
        await Act(s => s.GetRequiredService<IBountyExpirationService>().ProcessExpiredBountiesAsync());
        Assert.Equal(0, await Run(s => s.GetRequiredService<AppDbContext>().PaymentObligations.CountAsync(x => x.OccurrenceId == forcedOccurrence.Id)));
        var preserved = await Run(s => s.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync(x => x.Id == forcedOccurrence.Id));
        Assert.Equal(forcedDebtor, preserved.AssignedUserId); Assert.Equal(forcedOccurrence.DueDate, preserved.DueDate);
        await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(forcedOccurrence.Id, null, forcedDebtor));
        await Act(s => s.GetRequiredService<IBountyExpirationService>().ProcessExpiredBountiesAsync());
        Assert.Equal(0, await Run(s => s.GetRequiredService<AppDbContext>().PaymentObligations.CountAsync(x => x.OccurrenceId == forcedOccurrence.Id)));
        clock.Now = new DateTimeOffset(season.EndDate, TimeSpan.Zero).AddSeconds(1);
        await Act(s => s.GetRequiredService<ISeasonEndService>().FinalizeSeasonAsync(season.Id));
        await Act(s => s.GetRequiredService<ISeasonEndService>().FinalizeSeasonAsync(season.Id));
        Assert.Equal(count, await Run(s => s.GetRequiredService<AppDbContext>().SeasonRankings.CountAsync(x => x.SeasonId == season.Id)));
        var before = await Run(s => s.GetRequiredService<AppDbContext>().KarmaTransactions.CountAsync(x => x.SeasonId == season.Id));
        var late = normal[3]; await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(late.Id, null, late.AssignedUserId!.Value));
        Assert.Equal(before, await Run(s => s.GetRequiredService<AppDbContext>().KarmaTransactions.CountAsync(x => x.SeasonId == season.Id)));
        var pass = await Run(s => s.GetRequiredService<AppDbContext>().RewardRedemptions.Join(s.GetRequiredService<AppDbContext>().Rewards, r => r.RewardId, r => r.Id, (r, reward) => new { Redemption = r, Reward = reward }).Where(x => x.Reward.SeasonId == season.Id && x.Reward.Type == RewardType.CHORE_PASS).Select(x => x.Redemption).SingleAsync());
        await Act(s => s.GetRequiredService<IGamificationService>().ClaimRewardAsync(pass.Id, pass.UserId));
        Assert.Equal(RewardRedemptionStatus.CLAIMED, await Run(async s => (await s.GetRequiredService<AppDbContext>().RewardRedemptions.SingleAsync(x => x.Id == pass.Id)).Status));
        var retained = await Run(s => s.GetRequiredService<AppDbContext>().HouseMembers.SingleAsync(x => x.HouseId == house.Id && x.UserId == owner));
        Assert.Equal(retained.KarmaBalance, await Run(s => s.GetRequiredService<IGamificationService>().GetKarmaBalanceAsync(house.Id, owner)));
        var next = await Run(s => s.GetRequiredService<ISeasonService>().CreateSeasonAsync(house.Id, new CreateSeasonRequest { Name = "Pass season", StartDate = clock.Now.UtcDateTime, EndDate = clock.Now.AddDays(2).UtcDateTime, AllocationMethod = AllocationMethod.MANUAL }, owner));
        foreach (var user in users.Take(count))
        {
            await Act(s => s.GetRequiredService<ISeasonService>().SetAvailabilityAsync(next.Id, available, user.Id));
            if (user.Id != pass.UserId) await Act(s => s.GetRequiredService<IHouseService>().SetMemberConstraintAsync(house.Id, new SetMemberConstraintRequest { MaxChoresPerWeek = 20, MaxEffortMinutesPerDay = 15 }, user.Id));
        }
        await Run(s => s.GetRequiredService<IChoreService>().CreateChoreAsync(house.Id, new CreateChoreRequest { Name = "Pass coverage", Type = ChoreType.NORMAL, Difficulty = ChoreEffort.HARD, KarmaPoints = 50, FrequencyType = FrequencyType.CUSTOM, CustomDates = [DateOnly.FromDateTime(ChoreWars.Application.Services.ScheduleTime.Local(clock.Now.UtcDateTime)).AddDays(1)] }, owner));
        await Act(s => s.GetRequiredService<ISeasonService>().GenerateScheduleAsync(next.Id, owner));
        var covered = await Run(async s => (await s.GetRequiredService<ISeasonService>().GetOccurrencesAsync(next.Id, owner)).Single());
        await Act(s => s.GetRequiredService<IChoreAllocationService>().ManualAllocateAsync(next.Id, covered.Id, pass.UserId, owner));
        await Act(s => s.GetRequiredService<ISeasonService>().SubmitReviewAsync(next.Id, owner));
        var nextRevision = await Run(async s => (await s.GetRequiredService<AppDbContext>().Seasons.SingleAsync(x => x.Id == next.Id)).ScheduleRevision);
        foreach (var user in users.Take(count)) await Act(s => s.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(next.Id, user.Id, expectedRevision: nextRevision));
        await Assert.ThrowsAsync<ConflictException>(() => Act(s => s.GetRequiredService<IGamificationService>().UseChorePassAsync(pass.Id, covered.Id, pass.UserId)));
        Assert.Equal(RewardRedemptionStatus.CLAIMED, await Run(async s => (await s.GetRequiredService<AppDbContext>().RewardRedemptions.SingleAsync(x => x.Id == pass.Id)).Status));
        var replacement = users.Take(count).First(u => u.Id != pass.UserId).Id;
        await Act(s => s.GetRequiredService<IHouseService>().SetMemberConstraintAsync(house.Id, new SetMemberConstraintRequest { MaxChoresPerWeek = 20, MaxEffortMinutesPerDay = 60 }, replacement));
        await Act(s => s.GetRequiredService<IGamificationService>().UseChorePassAsync(pass.Id, covered.Id, pass.UserId));
        var changed = await Run(s => s.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync(x => x.Id == covered.Id));
        Assert.Equal(replacement, changed.AssignedUserId); Assert.False(changed.IsForcedReassigned);
        await Act(s => s.GetRequiredService<IChoreService>().CompleteChoreAsync(covered.Id, null, replacement));
        var credit = await Run(s => s.GetRequiredService<AppDbContext>().KarmaTransactions.SingleAsync(x => x.ReferenceId == covered.Id));
        Assert.Equal(50, credit.Amount); Assert.Equal(replacement, credit.UserId);
    }
}
