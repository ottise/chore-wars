using System.Text.Json;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class UrgentProposalTests
{
    private sealed class Realtime : IActionProposalRealtimePublisher, INotificationRealtimePublisher
    {
        public Task ProposalCreatedAsync(ActionProposalResponse value, CancellationToken ct = default) => Task.CompletedTask;
        public Task ProposalUpdatedAsync(ActionProposalResponse value, CancellationToken ct = default) => Task.CompletedTask;
        public Task PublishAsync(NotificationResponse value, CancellationToken ct = default) => Task.CompletedTask;
    }

    private static Task<PostgresFixture> Fixture() => PostgresFixture.CreateAsync(configure: services => {
        services.AddSingleton<IActionProposalRealtimePublisher, Realtime>();
        services.AddSingleton<INotificationRealtimePublisher, Realtime>();
    });

    private static async Task<ActionProposalResponse> Create(PostgresFixture f, CoreConcurrencyTests.Data data)
    {
        await using var scope = f.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.ChatRooms.Add(new ChatRoom { Id = Guid.NewGuid(), HouseId = data.HouseId, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();
        return await scope.ServiceProvider.GetRequiredService<IActionProposalService>().CreateProposalAsync(data.HouseId, new CreateProposalRequest {
            Type = ProposalType.URGENT_EVENT, Title = "Prepare for guests", Description = "Everyone agrees before tasks start",
            TargetUserIds = data.Users.Skip(1).ToList(),
            PayloadJson = JsonSerializer.Serialize(new UrgentEventPayload {
                SeasonId = data.SeasonId, DeadlineMinutes = 30,
                Chores = new() { new() { Name = "Clean table", AssignedUserId = data.Users[1], KarmaPoints = 10, Difficulty = ChoreEffort.EASY } }
            })
        }, data.Users[0]);
    }

    private static async Task Respond(PostgresFixture f, Guid proposal, Guid user)
    {
        await using var scope = f.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal,
            new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED }, user);
    }

    [PostgresFact]
    public async Task ConcurrentUrgentApprovalsCreateOneTaskWithSnapshotsAndNotifications()
    {
        await using var f = await Fixture(); var data = await CoreConcurrencyTests.Seed(f); var proposal = await Create(f, data);
        await Task.WhenAll(data.Users.Skip(1).Select(user => Respond(f, proposal.Id, user)));
        await Assert.ThrowsAsync<ConflictException>(() => Respond(f, proposal.Id, data.Users[1]));
        await using var scope = f.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var saved = await db.ActionProposals.SingleAsync(); Assert.Equal(ProposalStatus.APPROVED, saved.Status);
        var occurrence = await db.ChoreOccurrences.Include(o => o.Chore).SingleAsync(o => o.Chore.Name == "Clean table");
        Assert.Equal(15, occurrence.SnapshotMinutes); Assert.Equal(10, occurrence.SnapshotKarma);
        Assert.Equal(ChoreEffort.EASY, occurrence.SnapshotDifficulty); Assert.Equal(saved.ExpiresAt, occurrence.DueDate);
        Assert.Equal(5, await db.Notifications.CountAsync(n => n.TargetId == proposal.Id && n.TargetType == "AI_REQUEST"));
        var invitations = await db.Notifications.Where(n => n.TargetId == proposal.Id && n.TargetType == "AI_REQUEST" && n.Title == "Your AI assistant has a request").ToListAsync();
        Assert.Equal(data.Users.Skip(1).Order(), invitations.Select(n => n.UserId).Order());
        Assert.All(invitations, n => Assert.Contains("private AI conversation", n.Message));
        var outcomes = await db.Notifications.Where(n => n.TargetId == proposal.Id && n.Title == "AI request accepted").ToListAsync();
        Assert.Equal(data.Users.Order(), outcomes.Select(n => n.UserId).Order());
        var active = await scope.ServiceProvider.GetRequiredService<IActionProposalService>().GetActiveProposalsAsync(saved.RoomId, data.Users[0]);
        Assert.Contains(active, p => p.Id == proposal.Id);
    }

    [PostgresTheory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task UrgentApprovalRechecksSeasonAndMembership(bool endedSeason)
    {
        await using var f = await Fixture(); var data = await CoreConcurrencyTests.Seed(f); var proposal = await Create(f, data);
        await Respond(f, proposal.Id, data.Users[1]);
        await using (var change = f.Services.CreateAsyncScope()) {
            var db = change.ServiceProvider.GetRequiredService<AppDbContext>();
            if (endedSeason) (await db.Seasons.SingleAsync()).Status = SeasonStatus.COMPLETED;
            else (await db.HouseMembers.SingleAsync(m => m.UserId == data.Users[1])).Status = HouseMemberStatus.LEFT;
            await db.SaveChangesAsync();
        }
        if (endedSeason) await Assert.ThrowsAsync<ConflictException>(() => Respond(f, proposal.Id, data.Users[2]));
        else await Assert.ThrowsAsync<ForbiddenException>(() => Respond(f, proposal.Id, data.Users[2]));
        await using var scope = f.Services.CreateAsyncScope(); var read = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await read.ChoreOccurrences.CountAsync());
        Assert.Equal(ProposalStatus.PENDING, (await read.ActionProposals.SingleAsync()).Status);
        Assert.Equal(ConfirmationStatus.PENDING, (await read.ProposalConfirmations.SingleAsync(c => c.TargetUserId == data.Users[2])).Status);
    }

    [PostgresTheory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task ManualSwapTransfersResponsibilityOrRejectsNewBounty(bool bountyAfterProposal)
    {
        await using var f = await Fixture(); var data = await CoreConcurrencyTests.Seed(f);
        var otherId = Guid.NewGuid();
        await using (var create = f.Services.CreateAsyncScope()) {
            var db = create.ServiceProvider.GetRequiredService<AppDbContext>();
            var source = await db.ChoreOccurrences.SingleAsync();
            var tomorrow=DateOnly.FromDateTime(ScheduleTime.Local(DateTime.UtcNow)).AddDays(1);
            source.DueDate=ScheduleTime.Utc(tomorrow,1260);
            db.ChoreOccurrences.Add(new ChoreOccurrence { Id = otherId, ChoreId = source.ChoreId, SeasonId = data.SeasonId,
                AssignedUserId = data.Users[1], Status = ChoreOccurrenceStatus.ASSIGNED, DueDate = source.DueDate.AddDays(1), SnapshotKarma = 10, SnapshotMinutes = 30 });
            db.ChatRooms.Add(new ChatRoom { Id = Guid.NewGuid(), HouseId = data.HouseId });
            foreach (var user in data.Users.Take(2))
                foreach (var day in Enumerable.Range(0, 7))
                    db.MemberAvailabilities.Add(new MemberAvailability { Id = Guid.NewGuid(), SeasonId = data.SeasonId, UserId = user, DayOfWeek = (DayOfWeek)day, IsAvailable = true });
            await db.SaveChangesAsync();
        }
        Guid proposalId;
        await using (var create = f.Services.CreateAsyncScope()) {
            var proposal = await create.ServiceProvider.GetRequiredService<IActionProposalService>().CreateProposalAsync(data.HouseId, new CreateProposalRequest {
                Type = ProposalType.CHORE_SWAP, Title = "Swap our tasks", TargetUserIds = new() { data.Users[1] },
                PayloadJson = JsonSerializer.Serialize(new ChoreSwapPayload { SourceOccurrenceId = data.OccurrenceId, TargetOccurrenceId = otherId })
            }, data.Users[0]);
            proposalId = proposal.Id;
        }
        if (bountyAfterProposal) {
            await using var change = f.Services.CreateAsyncScope(); var db = change.ServiceProvider.GetRequiredService<AppDbContext>();
            db.ChoreBounties.Add(new ChoreBounty { Id = Guid.NewGuid(), ChoreOccurrenceId = data.OccurrenceId, PostedByUserId = data.Users[0], Amount = 10000,
                Status = BountyStatus.OPEN, CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddHours(1) });
            await db.SaveChangesAsync();
            await Assert.ThrowsAsync<ConflictException>(() => Respond(f, proposalId, data.Users[1]));
        }
        else {
            await Respond(f, proposalId, data.Users[1]);
            await Assert.ThrowsAsync<ConflictException>(() => Respond(f, proposalId, data.Users[1]));
        }
        await using var read = f.Services.CreateAsyncScope(); var database = read.ServiceProvider.GetRequiredService<AppDbContext>();
        var result = await database.ChoreOccurrences.Include(o => o.Responsibilities).SingleAsync(o => o.Id == data.OccurrenceId);
        Assert.Equal(bountyAfterProposal ? data.Users[0] : data.Users[1], result.AssignedUserId);
        if (!bountyAfterProposal) {
            Assert.Equal(2, result.Responsibilities.Count);
            Assert.Equal(data.Users[1], result.Responsibilities.Single(r => r.EndedAt == null).UserId);
            Assert.Equal("SWAP", result.Responsibilities.Single(r => r.EndedAt == null).Reason);
        }
    }
}
