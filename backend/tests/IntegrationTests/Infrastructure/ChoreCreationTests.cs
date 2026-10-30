using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class ChoreCreationTests {
    [PostgresFact]
    public async Task ConcurrentMemberCreatesAndRetriesPreserveHistoryAndDoNotDuplicateDates() {
        await using var f = await PostgresFixture.CreateAsync();
        var seed = await CoreConcurrencyTests.Seed(f);
        await using (var setup = f.Services.CreateAsyncScope()) {
            var db = setup.ServiceProvider.GetRequiredService<AppDbContext>();
            var historical = await db.ChoreOccurrences.SingleAsync();
            historical.Status = ChoreOccurrenceStatus.COMPLETED;
            historical.CompletedByUserId = seed.Users[0]; historical.CompletedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }
        var request = new CreateChoreRequest { ClientRequestId = Guid.NewGuid(), Name = "Concurrent addition", KarmaPoints = 10, FrequencyType = FrequencyType.DAILY };
        async Task<ChoreResponse> Create(Guid user) {
            await using var scope = f.Services.CreateAsyncScope();
            return await scope.ServiceProvider.GetRequiredService<IChoreService>().CreateChoreAsync(seed.HouseId, request, user);
        }
        var results = await Task.WhenAll(Create(seed.Users[1]), Create(seed.Users[1]), Create(seed.Users[2]));
        Assert.Equal(results[0].Id, results[1].Id);
        Assert.NotEqual(results[0].Id, results[2].Id);
        Assert.NotEmpty(results[0].OccurrenceIds);
        Assert.Equal("needs_assignment", results[0].AssignmentStatus);
        await using var read = f.Services.CreateAsyncScope();
        var dbRead = read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(3, await dbRead.Chores.CountAsync()); // original plus two additions
        Assert.Equal(5, (await dbRead.Seasons.SingleAsync()).ScheduleRevision);
        var occurrences = await dbRead.ChoreOccurrences.AsNoTracking().ToListAsync();
        Assert.Equal(ChoreOccurrenceStatus.COMPLETED, occurrences.Single(o => o.Id == seed.OccurrenceId).Status);
        Assert.All(occurrences.Where(o => o.Id != seed.OccurrenceId), o => Assert.True(o.DueDate > DateTime.UtcNow));
        Assert.All(occurrences.GroupBy(o => new { o.ChoreId, o.DueDate }), group => Assert.Single(group));
    }

    [PostgresFact]
    public async Task ReviewingAdditionResetsEveryApprovalAndBlocksStaleConfirmations() {
        await using var f = await PostgresFixture.CreateAsync();
        var seed = await CoreConcurrencyTests.Seed(f, SeasonStatus.REVIEWING);
        await using (var setup = f.Services.CreateAsyncScope()) {
            var db = setup.ServiceProvider.GetRequiredService<AppDbContext>();
            foreach (var confirmation in await db.SeasonConfirmations.ToListAsync()) confirmation.Status = ConfirmationStatus.CONFIRMED;
            (await db.Seasons.SingleAsync()).AllocationMethod = AllocationMethod.AUTOMATIC;
            await db.SaveChangesAsync();
        }
        await using (var create = f.Services.CreateAsyncScope()) {
            var response = await create.ServiceProvider.GetRequiredService<IChoreService>().CreateChoreAsync(seed.HouseId,
                new CreateChoreRequest { ClientRequestId = Guid.NewGuid(), Name = "Review addition", KarmaPoints = 10, FrequencyType = FrequencyType.DAILY }, seed.Users[1]);
            Assert.Equal(4, response.ScheduleRevision);
        }
        await using (var check = f.Services.CreateAsyncScope()) {
            var db = check.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(SeasonStatus.REVIEWING, (await db.Seasons.SingleAsync()).Status);
            var approvals = await db.SeasonConfirmations.ToListAsync();
            Assert.Equal(3, approvals.Count);
            Assert.All(approvals, c => { Assert.Equal(4, c.ScheduleRevision); Assert.Equal(ConfirmationStatus.PENDING, c.Status); });
            await Assert.ThrowsAsync<ConflictException>(() => check.ServiceProvider.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(seed.SeasonId, seed.Users[0], expectedRevision: 3));
        }
    }

    [PostgresTheory]
    [InlineData(false)] [InlineData(true)]
    public async Task ExplicitLegacyImportKeepsSourceAndMapsOnlyOneChoreInActiveSeason(bool existingEmptySnapshot) {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f);
        var template = Guid.NewGuid();
        await using (var setup = f.Services.CreateAsyncScope()) {
            var db = setup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Chores.Add(new Chore { Id = template, HouseId = seed.HouseId, Name = "Legacy routine", KarmaPoints = 10, FrequencyType = FrequencyType.DAILY });
            if (existingEmptySnapshot) db.Chores.Add(new Chore { Id = Guid.NewGuid(), HouseId = seed.HouseId, SeasonId = seed.SeasonId,
                SourceTemplateId = template, Name = "Existing legacy snapshot", KarmaPoints = 10, FrequencyType = FrequencyType.DAILY });
            await db.SaveChangesAsync();
        }
        async Task<ChoreResponse> Import() {
            await using var scope = f.Services.CreateAsyncScope();
            return await scope.ServiceProvider.GetRequiredService<IChoreService>().ImportRoutineAsync(seed.HouseId, seed.SeasonId, template, seed.Users[1]);
        }
        var results = await Task.WhenAll(Import(), Import());
        Assert.Equal(results[0].Id, results[1].Id); Assert.NotEmpty(results[0].OccurrenceIds);
        await using var read = f.Services.CreateAsyncScope(); var dbRead = read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null((await dbRead.Chores.SingleAsync(c => c.Id == template)).SeasonId);
        Assert.Equal(1, await dbRead.Chores.CountAsync(c => c.SourceTemplateId == template));
        Assert.True(await dbRead.ChoreOccurrences.AnyAsync(o => o.Id == seed.OccurrenceId));
    }

    [PostgresFact]
    public async Task OwnerCanResolveNewUnassignedActiveChoreWithoutChangingExistingAssignments() {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f);
        Guid occurrence;
        await using (var create = f.Services.CreateAsyncScope()) {
            var result = await create.ServiceProvider.GetRequiredService<IChoreService>().CreateChoreAsync(seed.HouseId,
                new CreateChoreRequest { ClientRequestId = Guid.NewGuid(), Name = "Needs assignment", KarmaPoints = 10, FrequencyType = FrequencyType.DAILY }, seed.Users[1]);
            occurrence = result.OccurrenceIds[0];
        }
        await using (var setup = f.Services.CreateAsyncScope()) {
            var db = setup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.MemberAvailabilities.AddRange(Enum.GetValues<DayOfWeek>().Select(day => new MemberAvailability {
                Id = Guid.NewGuid(), SeasonId = seed.SeasonId, UserId = seed.Users[1], DayOfWeek = day, IsAvailable = true
            }));
            await db.SaveChangesAsync();
        }
        await using (var denied = f.Services.CreateAsyncScope())
            await Assert.ThrowsAsync<ForbiddenException>(() => denied.ServiceProvider.GetRequiredService<IChoreAllocationService>().ManualAllocateAsync(seed.SeasonId, occurrence, seed.Users[1], seed.Users[1]));
        await using (var assign = f.Services.CreateAsyncScope())
            await assign.ServiceProvider.GetRequiredService<IChoreAllocationService>().ManualAllocateAsync(seed.SeasonId, occurrence, seed.Users[1], seed.Users[0]);
        await using var read = f.Services.CreateAsyncScope(); var dbRead = read.ServiceProvider.GetRequiredService<AppDbContext>();
        var added = await dbRead.ChoreOccurrences.SingleAsync(o => o.Id == occurrence);
        Assert.Equal(seed.Users[1], added.AssignedUserId); Assert.NotNull(added.PlannedStartAt);
        Assert.True(added.PlannedStartAt >= DateTime.UtcNow.AddMinutes(-1));
        Assert.Equal(seed.Users[0], (await dbRead.ChoreOccurrences.SingleAsync(o => o.Id == seed.OccurrenceId)).AssignedUserId);
    }
}
