using System.Text.Json;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;

namespace IntegrationTests.Infrastructure;

public class BonusTaskInvitationTests
{
    [PostgresFact]
    public async Task AllRecipientsMustConfirmBeforeAssignedBonusWorkIsCreatedOnce()
    {
        await using var fixture = await PostgresFixture.CreateAsync(configure: services =>
            services.AddScoped(_ => Mock.Of<IActionProposalRealtimePublisher>()));
        var seed = await CoreConcurrencyTests.Seed(fixture);
        Guid proposalId;
        Guid roomId;
        await using (var scope = fixture.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IActionProposalService>();
            roomId = (await scope.ServiceProvider.GetRequiredService<IChatService>()
                .GetHouseRoomAsync(seed.HouseId, seed.Users[0])).Id;
            var created = await service.CreateProposalAsync(seed.HouseId, new CreateProposalRequest
            {
                Type = ProposalType.URGENT_EVENT,
                Title = "Prepare a meal",
                TargetUserIds = [seed.Users[1], seed.Users[2]],
                ExpiresAt = DateTime.UtcNow.AddMinutes(30),
                PayloadJson = JsonSerializer.Serialize(new UrgentEventPayload
                {
                    SeasonId = seed.SeasonId,
                    DeadlineMinutes = 60,
                    Chores = seed.Users.Select((user, index) => new UrgentChoreItem
                    {
                        Name = "Preparation " + index,
                        AssignedUserId = user,
                        KarmaPoints = 10
                    }).ToList()
                })
            }, seed.Users[0]);
            proposalId = created.Id;
            var inbox = Assert.Single(await service.GetAssistantInboxAsync(seed.HouseId, seed.Users[1]));
            Assert.Equal(created.Id, inbox.Id);
            Assert.NotNull(inbox.CreatorName);
            await Assert.ThrowsAsync<ForbiddenException>(() => service.GetAssistantInboxAsync(seed.HouseId, Guid.NewGuid()));
            Assert.Equal(ProposalStatus.PENDING, created.Status);
            Assert.Contains(await service.GetActiveProposalsAsync(roomId, seed.Users[1]), p => p.Id == proposalId);
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Single(await db.ChoreOccurrences.ToListAsync());
            Assert.Equal(2, await db.Notifications.CountAsync(n => n.TargetId == proposalId && n.TargetType == "AI_REQUEST"));
            await Assert.ThrowsAsync<ForbiddenException>(() => service.RespondProposalAsync(proposalId,
                new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED }, seed.Users[0]));
        }
        await using (var scope = fixture.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IActionProposalService>();
            var first = await service.RespondProposalAsync(proposalId,
                new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED }, seed.Users[1]);
            Assert.Equal(ProposalStatus.PENDING, first.Status);
            Assert.Single(await scope.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.ToListAsync());
        }
        await using (var scope = fixture.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IActionProposalService>();
            var last = await service.RespondProposalAsync(proposalId,
                new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED }, seed.Users[2]);
            Assert.Equal(ProposalStatus.APPROVED, last.Status);
        }
        await using (var scope = fixture.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<IActionProposalService>();
            await Assert.ThrowsAsync<ConflictException>(() => service.RespondProposalAsync(proposalId,
                new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED }, seed.Users[2]));
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var bonus = await db.ChoreOccurrences.Include(o => o.Chore).Where(o => o.Id != seed.OccurrenceId).ToListAsync();
            Assert.Equal(ProposalStatus.APPROVED, Assert.Single(await service.GetAssistantInboxAsync(seed.HouseId, seed.Users[1])).Status);
            Assert.Equal(3, bonus.Count);
            Assert.All(bonus, o => {
                Assert.Equal(ChoreType.BONUS, o.Chore.Type);
                Assert.Equal(ChoreOccurrenceStatus.ASSIGNED, o.Status);
                Assert.Equal(seed.SeasonId, o.SeasonId);
                Assert.Contains(o.AssignedUserId!.Value, seed.Users);
            });
            Assert.Equal(3, bonus.Select(o => o.AssignedUserId).Distinct().Count());
            Assert.Single(bonus.Select(o => o.DueDate).Distinct());
        }
    }
    [PostgresFact]
    public async Task RejectedAndExpiredInvitationsNeverCreateBonusWork()
    {
        await using var fixture = await PostgresFixture.CreateAsync(configure: services =>
            services.AddScoped(_ => Mock.Of<IActionProposalRealtimePublisher>()));
        var seed = await CoreConcurrencyTests.Seed(fixture);
        await using var scope = fixture.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<IChatService>().GetHouseRoomAsync(seed.HouseId, seed.Users[0]);
        var service = scope.ServiceProvider.GetRequiredService<IActionProposalService>();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        foreach (var expired in new[] { false, true })
        {
            var proposal = await service.CreateProposalAsync(seed.HouseId, new CreateProposalRequest
            {
                Type = ProposalType.URGENT_EVENT,
                Title = "Prepare dinner",
                TargetUserIds = [seed.Users[1]],
                ExpiresAt = DateTime.UtcNow.AddMinutes(30),
                PayloadJson = JsonSerializer.Serialize(new UrgentEventPayload
                {
                    SeasonId = seed.SeasonId,
                    DeadlineMinutes = 60,
                    Chores = [new() { Name = "Wash vegetables", KarmaPoints = 10, AssignedUserId = seed.Users[1] }]
                })
            }, seed.Users[0]);
            if (expired)
            {
                (await db.ActionProposals.SingleAsync(p => p.Id == proposal.Id)).ExpiresAt = DateTime.UtcNow.AddMinutes(-1);
                await db.SaveChangesAsync();
                await Assert.ThrowsAsync<ConflictException>(() => service.RespondProposalAsync(proposal.Id,
                    new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED }, seed.Users[1]));
            }
            else
            {
                var rejected = await service.RespondProposalAsync(proposal.Id,
                    new RespondProposalRequest { Status = ConfirmationStatus.REJECTED }, seed.Users[1]);
                Assert.Equal(ProposalStatus.REJECTED, rejected.Status);
                Assert.Equal(2, await db.Notifications.CountAsync(n => n.TargetId == proposal.Id &&
                    n.TargetType == "AI_REQUEST" && n.Title == "AI request declined"));
            }
            Assert.Empty(await service.GetAssistantInboxAsync(seed.HouseId, seed.Users[2]));
            Assert.Contains(await service.GetAssistantInboxAsync(seed.HouseId, seed.Users[1]), p => p.Id == proposal.Id);
            Assert.Single(await db.ChoreOccurrences.ToListAsync());
            Assert.Empty(await db.Chores.Where(c => c.Type == ChoreType.BONUS).ToListAsync());
        }
    }

}
