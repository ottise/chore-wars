using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class MemberJoinRedistributionTests
{
    [PostgresFact]
    public async Task JoinSharesFutureChoresKeepsTimesAndHistoryAndDuplicateJoinDoesNotRedistribute()
    {
        await using var f = await PostgresFixture.CreateAsync();
        var seed = await CoreConcurrencyTests.Seed(f);
        var newcomer = Guid.NewGuid();
        string code;
        var originals = new Dictionary<Guid, DateTime>();
        Guid locked;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            code = (await db.Houses.SingleAsync()).InviteCode;
            db.Users.Add(new User { Id = newcomer, Email = "joining@example.test", DisplayName = "New member", PasswordHash = "test-only" });
            var past = await db.ChoreOccurrences.SingleAsync();
            past.Status = ChoreOccurrenceStatus.COMPLETED; past.CompletedByUserId = seed.Users[0]; past.CompletedAt = DateTime.UtcNow;
            for (var i = 0; i < 4; i++)
            {
                var start = DateTime.UtcNow.Date.AddDays(1).AddHours(2 + i);
                var task = new ChoreOccurrence
                {
                    Id = Guid.NewGuid(),
                    ChoreId = past.ChoreId,
                    SeasonId = seed.SeasonId,
                    AssignedUserId = seed.Users[0],
                    PlannedStartAt = start,
                    DueDate = start.AddMinutes(30),
                    SnapshotKarma = 10,
                    SnapshotMinutes = 30,
                    Status = ChoreOccurrenceStatus.ASSIGNED
                };
                db.ChoreOccurrences.Add(task); originals.Add(task.Id, start);
            }
            var bountyTask = new ChoreOccurrence
            {
                Id = Guid.NewGuid(),
                ChoreId = past.ChoreId,
                SeasonId = seed.SeasonId,
                AssignedUserId = seed.Users[0],
                PlannedStartAt = DateTime.UtcNow.AddDays(1),
                DueDate = DateTime.UtcNow.AddDays(1).AddHours(1),
                SnapshotKarma = 50,
                SnapshotMinutes = 30,
                Status = ChoreOccurrenceStatus.ASSIGNED
            };
            locked = bountyTask.Id; db.ChoreOccurrences.Add(bountyTask);
            db.ChoreBounties.Add(new ChoreBounty
            {
                Id = Guid.NewGuid(),
                ChoreOccurrenceId = locked,
                PostedByUserId = seed.Users[0],
                Amount = 10000,
                ExpiresAt = bountyTask.DueDate,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }
        await using (var scope = f.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<IHouseService>().JoinHouseAsync(new JoinHouseRequest { InviteCode = code }, newcomer);
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var tasks = await db.ChoreOccurrences.Include(o => o.Responsibilities).ToListAsync();
            // Protected bounty workload still counts in fairness; all four transferable tasks balance the donor.
            Assert.Equal(4, tasks.Count(o => o.AssignedUserId == newcomer));
            Assert.All(tasks.Where(t => originals.ContainsKey(t.Id)), t => Assert.Equal(originals[t.Id], t.PlannedStartAt));
            Assert.Equal(seed.Users[0], tasks.Single(t => t.Id == locked).AssignedUserId);
            Assert.Equal(ChoreOccurrenceStatus.COMPLETED, tasks.Single(t => t.Id == seed.OccurrenceId).Status);
            Assert.All(tasks.Where(t => t.AssignedUserId == newcomer), t =>
            {
                Assert.Single(t.Responsibilities, r => r.EndedAt == null && r.UserId == newcomer && r.Reason == "MEMBER_JOINED");
                Assert.Single(t.Responsibilities, r => r.EndedAt != null && r.UserId == seed.Users[0]);
            });
            Assert.Equal(4, (await db.Seasons.SingleAsync()).ScheduleRevision);
            Assert.Equal(2, await db.Notifications.CountAsync(n => n.Title == "Chore schedule updated"));
            await Assert.ThrowsAsync<ConflictException>(() => scope.ServiceProvider.GetRequiredService<IHouseService>()
                .JoinHouseAsync(new JoinHouseRequest { InviteCode = code }, newcomer));
            Assert.Equal(4, (await db.Seasons.SingleAsync()).ScheduleRevision);
        }
    }

    [PostgresFact]
    public async Task ExplicitlyUnavailableNewMemberReceivesNoConflictingChores()
    {
        await using var f = await PostgresFixture.CreateAsync();
        var seed = await CoreConcurrencyTests.Seed(f);
        var newcomer = Guid.NewGuid(); string code;
        await using (var scope = f.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            code = (await db.Houses.SingleAsync()).InviteCode;
            db.Users.Add(new User { Id = newcomer, Email = "unavailable@example.test", DisplayName = "Unavailable", PasswordHash = "test-only" });
            db.MemberAvailabilities.AddRange(Enumerable.Range(0, 7).Select(day => new MemberAvailability
            {
                Id = Guid.NewGuid(),
                UserId = newcomer,
                SeasonId = seed.SeasonId,
                DayOfWeek = (DayOfWeek)day,
                IsAvailable = false
            }));
            var original = await db.ChoreOccurrences.SingleAsync();
            db.ChoreOccurrences.Add(new ChoreOccurrence
            {
                Id = Guid.NewGuid(),
                ChoreId = original.ChoreId,
                SeasonId = seed.SeasonId,
                AssignedUserId = seed.Users[0],
                DueDate = DateTime.UtcNow.AddDays(1),
                SnapshotKarma = 10,
                SnapshotMinutes = 30,
                Status = ChoreOccurrenceStatus.ASSIGNED
            });
            await db.SaveChangesAsync();
        }
        await using var join = f.Services.CreateAsyncScope();
        await join.ServiceProvider.GetRequiredService<IHouseService>().JoinHouseAsync(new JoinHouseRequest { InviteCode = code }, newcomer);
        Assert.Equal(0, await join.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.CountAsync(o => o.AssignedUserId == newcomer));
    }
}
