using System.Text.Json;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging.Abstractions;
using ChoreWars.Infrastructure.AI;

namespace IntegrationTests.Infrastructure;

public class AIHousekeeperTests
{
    private sealed class DaytimeClock(DateTime utc) : TimeProvider {
        public override DateTimeOffset GetUtcNow() => new(utc);
    }
    [PostgresFact]
    public async Task PromptUrgentPlanNotifiesOnlyNamedTargetAndRequiresApproval()
    {
        var client=new Mock<IAIHousekeeperClient>();
        var now=DateTime.UtcNow.Date.AddHours(3);
        await using var f=await Fixture(s=>{s.AddScoped(_=>client.Object);s.AddSingleton<TimeProvider>(new DaytimeClock(now));});
        var data=await CoreConcurrencyTests.Seed(f);
        var readyBy=now.AddHours(2);
        client.Setup(c=>c.PostAsync(data.HouseId,data.Users[0],"/v1/urgent/plan",It.IsAny<object>(),It.IsAny<CancellationToken>()))
            .ReturnsAsync(JsonSerializer.SerializeToElement(new{status="READY",urgent_payload=new UrgentEventPayload {
                SeasonId=data.SeasonId,DeadlineMinutes=120,ReadyByUtc=readyBy,GuestCount=10,Title="Party preparation",PlanVersion="blitz-v1",
                Chores=[new(){Name="Clean table",PlanKey="table",PlannedOffsetMinutes=0,AssignedUserId=data.Users[1],Difficulty=ChoreEffort.EASY,KarmaPoints=0}]
            }}));
        await using var scope=f.Services.CreateAsyncScope();
        var database=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        foreach (var user in data.Users)
            foreach (var day in Enum.GetValues<DayOfWeek>())
                database.MemberAvailabilities.Add(new MemberAvailability{Id=Guid.NewGuid(),SeasonId=data.SeasonId,UserId=user,
                    DayOfWeek=day,IsAvailable=true,Slots=[new(){Id=Guid.NewGuid(),StartMinute=0,EndMinute=1440}]});
        await database.SaveChangesAsync();
        await scope.ServiceProvider.GetRequiredService<IChatService>().GetHouseRoomAsync(data.HouseId,data.Users[0]);
        var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
        var request=new AIGenerateRequest {
            ClientRequestId=Guid.NewGuid(),SeasonId=data.SeasonId,Kind=AIConstants.Urgent,
            Text="Member 1 should clean the table within 60 minutes",DeadlineMinutes=60,
            ReadyBy=new DateTimeOffset(readyBy),GuestCount=10,
            ParticipantIds=[data.Users[0],data.Users[1]]
        };
        var plan=await service.RequestUrgentAsync(data.HouseId,data.Users[0],request,default);
        var id=plan.GetProperty("id").GetGuid();
        Assert.NotEqual(JsonValueKind.Null,plan.GetProperty("proposal_id").ValueKind);
        await service.RequestUrgentAsync(data.HouseId,data.Users[0],request,default);
        await service.AcceptAsync(data.HouseId,data.Users[0],id,default);
        var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var proposal=await db.ActionProposals.SingleAsync();
        Assert.Equal(ProposalStatus.PENDING,proposal.Status);
        Assert.Contains("10 guests",proposal.Description);
        Assert.Single(await db.ChoreOccurrences.ToListAsync());
        var notice=Assert.Single(await db.Notifications.ToListAsync());
        Assert.Equal(data.Users[1],notice.UserId);
        Assert.Equal(proposal.Id,notice.TargetId);
        Assert.Equal(NotificationTargets.AiRequest,notice.TargetType);
        var approved=await scope.ServiceProvider.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal.Id,
            new ChoreWars.Application.DTOs.Proposal.RespondProposalRequest{Status=ConfirmationStatus.CONFIRMED},data.Users[1]);
        Assert.Equal(ProposalStatus.APPROVED,approved.Status);
        var task=await db.ChoreOccurrences.Include(o=>o.Chore).SingleAsync(o=>o.Chore.Name=="Clean table");
        Assert.Equal(data.Users[1],task.AssignedUserId);
        Assert.Equal(readyBy,task.DueDate);
    }

    [PostgresFact]
    public async Task PrivateAssistantDoesNotRequireBackgroundAnalysisOrGrantChatConsent()
    {
        var client=new Mock<IAIHousekeeperClient>();
        client.Setup(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/interpret",It.IsAny<object>(),It.IsAny<CancellationToken>()))
            .ReturnsAsync(JsonSerializer.SerializeToElement(new{summary="Please confirm tomorrow's availability."}));
        await using var f=await Fixture(s=>s.AddScoped(_=>client.Object));
        var data=await CoreConcurrencyTests.Seed(f);
        await using var scope=f.Services.CreateAsyncScope();
        var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
        await service.SettingsAsync(data.HouseId,data.Users[0],false,false,default);
        var result=await service.InterpretAsync(data.HouseId,data.Users[1],new AITextRequest{Text="I am busy tomorrow evening."},false,default);
        Assert.False(string.IsNullOrWhiteSpace(result.GetProperty("summary").GetString()));
        var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False((await db.HouseAiSettings.SingleAsync()).Enabled);
        Assert.Empty(await db.MemberAiConsents.ToListAsync());
        Assert.Empty(await db.AIChatInsights.ToListAsync());
        await Assert.ThrowsAsync<ConflictException>(()=>service.InterpretAsync(data.HouseId,data.Users[1],new AITextRequest{Text="I am busy tomorrow evening."},true,default));
        await service.SettingsAsync(data.HouseId,data.Users[0],true,true,default);
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.InterpretAsync(data.HouseId,data.Users[1],new AITextRequest{Text="I am busy tomorrow evening."},true,default));
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.ChatInsightsAsync(data.HouseId,data.Users[1],default));
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.InterpretAsync(data.HouseId,Guid.NewGuid(),new AITextRequest{Text="Hello"},false,default));
        client.Verify(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/interpret",It.IsAny<object>(),It.IsAny<CancellationToken>()),Times.Once);
    }

    [PostgresFact]
    public async Task DraftEvidenceUploadIsRejectedBeforeStorageAndDoesNotBlockRegeneration() {
        var storage=new Mock<IMediaStorage>();
        await using var f=await Fixture(s=>s.AddScoped(_=>storage.Object));var data=await CoreConcurrencyTests.Seed(f,SeasonStatus.DRAFT);
        var bytes=new byte[]{255,216,255,1,2,3,4,5,6,7,8,9};
        await using(var scope=f.Services.CreateAsyncScope()) {
            await Assert.ThrowsAsync<ConflictException>(()=>scope.ServiceProvider.GetRequiredService<IEvidenceService>().UploadAsync(data.OccurrenceId,data.Users[0],Guid.NewGuid(),bytes,default));
            Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().ChoreEvidence.ToListAsync());
        }
        storage.Verify(s=>s.WriteAsync(It.IsAny<string>(),It.IsAny<byte[]>(),It.IsAny<CancellationToken>()),Times.Never);
        await using(var scope=f.Services.CreateAsyncScope())await scope.ServiceProvider.GetRequiredService<ISeasonService>().GenerateScheduleAsync(data.SeasonId,data.Users[0]);
        await using var read=f.Services.CreateAsyncScope();
        Assert.False(await read.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.AnyAsync(o=>o.Id==data.OccurrenceId));
    }

    [PostgresFact]
    public async Task ReplacingAndClearingPreferencesKeepsDeletionEvidenceInAtomicOutbox() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f,SeasonStatus.DRAFT);
        Guid choreId;
        await using(var read=f.Services.CreateAsyncScope())choreId=await read.ServiceProvider.GetRequiredService<AppDbContext>().Chores.Select(c=>c.Id).SingleAsync();
        foreach(var type in new PreferenceType?[]{PreferenceType.PREFERRED,PreferenceType.DISLIKED,null}) {
            await using var scope=f.Services.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<IHouseService>().SetMemberPreferencesAsync(data.HouseId,new SetMemberPreferencesRequest{Preferences=type.HasValue?[new(){ChoreId=choreId,Type=type.Value}]:[]},data.Users[1]);
        }
        await using var check=f.Services.CreateAsyncScope();var db=check.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Empty(await db.MemberPreferences.ToListAsync());
        var events=(await db.OutboxMessages.Where(m=>m.Topic==AIConstants.TelemetryTopic).ToListAsync()).Select(m=>JsonSerializer.Deserialize<JsonElement>(m.Payload)).Where(e=>e.GetProperty("event_type").GetString()=="preference.upsert").OrderBy(e=>e.GetProperty("house_sequence").GetInt64()).ToList();
        Assert.Equal(4,events.Count);
        Assert.Equal(2,events.Count(e=>e.GetProperty("payload").GetProperty("deleted").GetBoolean()));
        Assert.All(events,e=>Assert.Equal(data.Users[1],e.GetProperty("payload").GetProperty("member_id").GetGuid()));
        Assert.Equal("DISLIKED",events[^1].GetProperty("payload").GetProperty("type").GetString());
        Assert.True(events[^1].GetProperty("payload").GetProperty("deleted").GetBoolean());
        Assert.All(events,e=>Assert.True(e.GetProperty("batch_last_sequence").GetInt64()>=e.GetProperty("house_sequence").GetInt64()));
    }

    [PostgresFact]
    public async Task ObservedDraftTaskDoesNotPreventScheduleRegeneration() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f,SeasonStatus.DRAFT);
        await using(var scope=f.Services.CreateAsyncScope()) {
            var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            await service.SettingsAsync(data.HouseId,data.Users[0],true,false,default);
            await service.ObserveAsync(data.HouseId,data.Users[1],new AIObservationRequest{ClientRequestId=Guid.NewGuid(),EntityId=data.OccurrenceId,Kind=AIObservationKinds.TaskOpened},default);
        }
        await using(var scope=f.Services.CreateAsyncScope())await scope.ServiceProvider.GetRequiredService<ISeasonService>().GenerateScheduleAsync(data.SeasonId,data.Users[0]);
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.ChoreOccurrences.AnyAsync(o=>o.Id==data.OccurrenceId));
        Assert.True(await db.ChoreOccurrences.AnyAsync(o=>o.SeasonId==data.SeasonId));
        Assert.Equal(data.OccurrenceId,(await db.AIObservations.SingleAsync()).OccurrenceId);
    }

    [PostgresFact]
    public async Task ObservedBountyOpenIsScopedIdempotentAndDoesNotMeanAcceptance() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f);var bountyId=Guid.NewGuid();
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.ChoreBounties.Add(new ChoreBounty{Id=bountyId,ChoreOccurrenceId=data.OccurrenceId,PostedByUserId=data.Users[0],Amount=10000,Status=BountyStatus.OPEN,CreatedAt=DateTime.UtcNow,ExpiresAt=DateTime.UtcNow.AddHours(1)});
            await db.SaveChangesAsync();await scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>().SettingsAsync(data.HouseId,data.Users[0],true,false,default);
        }
        var request=new AIObservationRequest{ClientRequestId=Guid.NewGuid(),EntityId=bountyId,Kind=AIObservationKinds.BountyOpened};
        await using(var scope=f.Services.CreateAsyncScope()) {
            var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            var first=await service.ObserveAsync(data.HouseId,data.Users[1],request,default);
            var retry=await service.ObserveAsync(data.HouseId,data.Users[1],request,default);
            Assert.Equal(first.GetProperty("id").GetGuid(),retry.GetProperty("id").GetGuid());
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Single(await db.AIObservations.ToListAsync());
            Assert.Equal(BountyStatus.OPEN,(await db.ChoreBounties.SingleAsync()).Status);
            Assert.Equal(data.Users[0],(await db.ChoreOccurrences.SingleAsync()).AssignedUserId);
            Assert.Empty(await db.PaymentObligations.ToListAsync());
            await Assert.ThrowsAsync<NotFoundException>(()=>service.ObserveAsync(data.HouseId,data.Users[1],new AIObservationRequest{ClientRequestId=Guid.NewGuid(),EntityId=Guid.NewGuid(),Kind=AIObservationKinds.TaskOpened},default));
        }
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            (await db.HouseMembers.SingleAsync(m=>m.UserId==data.Users[1])).Status=HouseMemberStatus.LEFT;await db.SaveChangesAsync();
        }
        await using var after=f.Services.CreateAsyncScope();
        await Assert.ThrowsAsync<ForbiddenException>(()=>after.ServiceProvider.GetRequiredService<IAIHousekeeperService>().ObserveAsync(data.HouseId,data.Users[1],request,default));
    }

    [PostgresFact]
    public async Task EnablingTelemetryDoesNotBackfillPastResponsibilityWithCurrentFeatures() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f);
        var episode=new ChoreResponsibility{Id=Guid.NewGuid(),OccurrenceId=data.OccurrenceId,UserId=data.Users[0],Reason="INITIAL",StartedAt=DateTime.UtcNow.AddHours(-2),Deadline=DateTime.UtcNow.AddHours(1)};
        await using(var oldScope=f.Services.CreateAsyncScope()) {
            var options=oldScope.ServiceProvider.GetRequiredService<IOptions<AIOptions>>().Value;options.Enabled=false;
            var oldDb=oldScope.ServiceProvider.GetRequiredService<AppDbContext>();
            oldDb.Set<ChoreResponsibility>().Add(episode);await oldDb.SaveChangesAsync();options.Enabled=true;
        }
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var existing=await db.Set<ChoreResponsibility>().SingleAsync(r=>r.Id==episode.Id);
        existing.EndedAt=DateTime.UtcNow;existing.CompletedByUserId=data.Users[0];await db.SaveChangesAsync();
        Assert.Empty(await db.AIResponsibilityContextSnapshots.ToListAsync());
        var payload=(await db.OutboxMessages.Where(m=>m.Topic==AIConstants.TelemetryTopic).ToListAsync()).Select(m=>JsonSerializer.Deserialize<JsonElement>(m.Payload)).Single(e=>e.GetProperty("entity_id").GetGuid()==episode.Id);
        Assert.Equal(JsonValueKind.Null,payload.GetProperty("payload").GetProperty("snapshot_id").ValueKind);
    }

    [PostgresFact]
    public async Task AvailabilityAndScheduleRemainUnchangedUntilAllAffectedMembersApprove() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f);var change=await PrepareReplan(f,data);
        var date=DateOnly.FromDateTime(ScheduleTime.Local(change.Changes[0].PlannedStartAt));
        change.AvailabilityChanges=[new(){UserId=data.Users[1],LocalDate=date,Slots=[new(){StartMinute=600,EndMinute=1260}]}];
        foreach(var item in change.Changes)item.PlannedStartAt=ScheduleTime.Utc(date,600);
        Guid proposal;
        await using(var scope=f.Services.CreateAsyncScope()) {
            proposal=(await scope.ServiceProvider.GetRequiredService<IActionProposalService>().CreateProposalAsync(data.HouseId,new CreateProposalRequest{Type=ProposalType.SCHEDULE_REPLAN,Title="Confirm changed availability",PayloadJson=JsonSerializer.Serialize(change),TargetUserIds=data.Users.Skip(1).ToList(),ExpiresAt=DateTime.UtcNow.AddMinutes(10)},data.Users[0])).Id;
            Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().MemberAvailabilityExceptions.ToListAsync());
        }
        await using(var scope=f.Services.CreateAsyncScope()) {
            await scope.ServiceProvider.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal,new RespondProposalRequest{Status=ConfirmationStatus.CONFIRMED},data.Users[1]);
            Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().MemberAvailabilityExceptions.ToListAsync());
        }
        await using(var scope=f.Services.CreateAsyncScope())await scope.ServiceProvider.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal,new RespondProposalRequest{Status=ConfirmationStatus.CONFIRMED},data.Users[2]);
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        var saved=await db.MemberAvailabilityExceptions.SingleAsync();Assert.Equal(data.Users[1],saved.UserId);Assert.Equal(date,saved.LocalDate);
        var episode=await db.Set<ChoreResponsibility>().SingleAsync(r=>r.Reason=="REPLAN" && r.UserId==data.Users[1]);
        var snapshot=await db.AIResponsibilityContextSnapshots.SingleAsync(s=>s.EpisodeId==episode.Id);
        using var context=JsonDocument.Parse(snapshot.PayloadJson);
        Assert.Equal(600,context.RootElement.GetProperty("date_exceptions").GetProperty(date.ToString("yyyy-MM-dd"))[0].GetProperty("start").GetInt32());
        foreach(var item in change.Changes)Assert.Equal(item.PlannedStartAt,(await db.ChoreOccurrences.SingleAsync(o=>o.Id==item.OccurrenceId)).PlannedStartAt);
        Assert.Equal(4,(await db.Seasons.SingleAsync()).ScheduleRevision);
    }

    [PostgresFact]
    public async Task BusyDeclarationInActiveSeasonOnlyCreatesPreviewAndRetryReusesIt() {
        var client=new Mock<IAIHousekeeperClient>();
        client.Setup(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/schedules/replan",It.IsAny<object>(),It.IsAny<CancellationToken>())).ReturnsAsync(JsonSerializer.SerializeToElement(new{status="INFEASIBLE",reason="No feasible schedule",tasks=Array.Empty<object>()}));
        await using var f=await Fixture(s=>s.AddScoped(_=>client.Object));var data=await CoreConcurrencyTests.Seed(f);await PrepareReplan(f,data);
        var request=new AIAvailabilityChangeRequest{ClientRequestId=Guid.NewGuid(),SeasonId=data.SeasonId,LocalDate=DateOnly.FromDateTime(ScheduleTime.Local(DateTime.UtcNow)).AddDays(1),Busy=true,StartMinute=480,EndMinute=600};
        await using var scope=f.Services.CreateAsyncScope();var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
        await service.SettingsAsync(data.HouseId,data.Users[0],true,false,default);
        var first=await service.ConfirmAvailabilityAsync(data.HouseId,data.Users[1],request,default);
        var retry=await service.ConfirmAvailabilityAsync(data.HouseId,data.Users[1],request,default);
        Assert.Equal(first.GetProperty("id").GetGuid(),retry.GetProperty("id").GetGuid());
        var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();Assert.Empty(await db.MemberAvailabilityExceptions.ToListAsync());
        Assert.Equal(3,(await db.Seasons.SingleAsync()).ScheduleRevision);
        client.Verify(c=>c.PostAsync(data.HouseId,data.Users[1],"/v1/schedules/replan",It.IsAny<object>(),It.IsAny<CancellationToken>()),Times.Once);
    }

    [PostgresFact]
    public async Task ActivatingReviewedSeasonCreatesInitialEpisodesAndSourceSnapshots() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f,SeasonStatus.REVIEWING);
        foreach(var member in data.Users) {
            await using var scope=f.Services.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(data.SeasonId,member,expectedRevision:3);
        }
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(SeasonStatus.ACTIVE,(await db.Seasons.SingleAsync()).Status);
        Assert.Equal("INITIAL",(await db.Set<ChoreResponsibility>().SingleAsync()).Reason);
        Assert.Single(await db.AIResponsibilityContextSnapshots.ToListAsync());
    }
    private static Task<PostgresFixture> Fixture(Action<IServiceCollection>? configure=null) => PostgresFixture.CreateAsync(new(){["AI:Enabled"]="true"},services=> {
        services.AddScoped(_=>Mock.Of<IActionProposalRealtimePublisher>());
        services.AddScoped(_=>Mock.Of<INotificationRealtimePublisher>());
        configure?.Invoke(services);
    });

    [PostgresFact]
    public async Task AutomaticChatInsightIsPrivateAndConsentRevocationRemovesItsLineage() {
        var client=new Mock<IAIHousekeeperClient>();
        client.Setup(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/interpret",It.IsAny<object>(),It.IsAny<CancellationToken>())).ReturnsAsync(JsonSerializer.SerializeToElement(new{intent="availability",summary="Cần xác nhận lịch rảnh.",missing_fields=new[]{"date"},evidence_quotes=new[]{"tôi bận"},requires_confirmation=true}));
        await using var f=await Fixture(s=>s.AddScoped(_=>client.Object));var data=await CoreConcurrencyTests.Seed(f);
        await using(var scope=f.Services.CreateAsyncScope()) {
            var ai=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            await ai.SettingsAsync(data.HouseId,data.Users[0],true,true,default);
            await ai.ConsentAsync(data.HouseId,data.Users[1],true,default);
            var chat=scope.ServiceProvider.GetRequiredService<IChatService>();var room=await chat.GetHouseRoomAsync(data.HouseId,data.Users[1]);
            await chat.CreateMessageAsync(room.Id,data.Users[1],"Ngày mai tôi bận.");
            await chat.CreateMessageAsync(room.Id,data.Users[2],"Tin nhắn chưa opt-in.");
        }
        var worker=new AIChatInsightWorker(f.Services.GetRequiredService<IServiceScopeFactory>(),Options.Create(new AIOptions{Enabled=true}),NullLogger<AIChatInsightWorker>.Instance);
        await worker.ProcessOneAsync(default);
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();Assert.Equal("READY",(await db.AIChatInsights.SingleAsync()).Status);
            var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            await Assert.ThrowsAsync<ForbiddenException>(()=>service.ChatInsightsAsync(data.HouseId,data.Users[0],default));
            await service.ConsentAsync(data.HouseId,data.Users[1],false,default);
            Assert.Empty(await db.AIChatInsights.ToListAsync());Assert.Equal(2,await db.ChatMessages.CountAsync());
        }
        client.Verify(c=>c.PostAsync(data.HouseId,data.Users[1],"/v1/interpret",It.IsAny<object>(),It.IsAny<CancellationToken>()),Times.Once);
    }

    [PostgresFact]
    public async Task EvidenceRetryIsIdempotentPrivateAndVisionCannotComplete() {
        var files=new Dictionary<string,byte[]>();var storage=new Mock<IMediaStorage>();
        storage.Setup(s=>s.WriteAsync(It.IsAny<string>(),It.IsAny<byte[]>(),It.IsAny<CancellationToken>())).Callback<string,byte[],CancellationToken>((key,data,_)=>files.Add(key,data)).Returns(Task.CompletedTask);
        storage.Setup(s=>s.ReadAsync(It.IsAny<string>(),It.IsAny<CancellationToken>())).Returns<string,CancellationToken>((key,_)=>Task.FromResult<Stream>(new MemoryStream(files[key])));
        var client=new Mock<IAIHousekeeperClient>();client.Setup(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/vision/verify-proof",It.IsAny<object>(),It.IsAny<CancellationToken>())).ReturnsAsync(JsonSerializer.SerializeToElement(new{result="UNCERTAIN",observations=Array.Empty<string>(),limitations=new[]{"Cần người dùng xác nhận."},can_complete_automatically=false}));
        await using var f=await Fixture(s=>{s.AddScoped(_=>storage.Object);s.AddScoped(_=>client.Object);});var data=await CoreConcurrencyTests.Seed(f);
        var bytes=new byte[]{255,216,255,1,2,3,4,5,6,7,8,9};var request=Guid.NewGuid();Guid evidenceId;
        await using(var scope=f.Services.CreateAsyncScope()) {
            var service=scope.ServiceProvider.GetRequiredService<IEvidenceService>();
            var first=await service.UploadAsync(data.OccurrenceId,data.Users[0],request,bytes,default);
            evidenceId=first.GetProperty("id").GetGuid();var retry=await service.UploadAsync(data.OccurrenceId,data.Users[0],request,bytes,default);
            Assert.Equal(evidenceId,retry.GetProperty("id").GetGuid());Assert.Single(files);
            await Assert.ThrowsAsync<ForbiddenException>(()=>service.ReadAsync(evidenceId,data.Users[1],default));
            await scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>().SettingsAsync(data.HouseId,data.Users[0],true,false,default);
            await service.VerifyAsync(data.OccurrenceId,evidenceId,data.Users[0],default);
            Assert.Equal(ChoreOccurrenceStatus.ASSIGNED,(await scope.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync()).Status);
        }
        await using(var scope=f.Services.CreateAsyncScope())await scope.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(data.OccurrenceId,new CompleteChoreRequest{EvidenceId=evidenceId},data.Users[0]);
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(evidenceId,(await db.ChoreOccurrences.SingleAsync()).EvidenceId);Assert.NotNull((await db.ChoreEvidence.SingleAsync()).AttachedAt);
    }

    private static async Task<ScheduleChangePayload> PrepareReplan(PostgresFixture f,CoreConcurrencyTests.Data data) {
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var day=DateOnly.FromDateTime(ScheduleTime.Local(DateTime.UtcNow)).AddDays(1);var original=await db.ChoreOccurrences.SingleAsync();
        original.DueDate=ScheduleTime.Utc(day,1260);original.PlannedStartAt=ScheduleTime.Utc(day,480);
        foreach(var user in data.Users.Skip(1))db.ChoreOccurrences.Add(new ChoreOccurrence{Id=Guid.NewGuid(),ChoreId=original.ChoreId,SeasonId=data.SeasonId,AssignedUserId=user,DueDate=original.DueDate,PlannedStartAt=original.PlannedStartAt,SnapshotMinutes=30,SnapshotKarma=10,Status=ChoreOccurrenceStatus.ASSIGNED});
        foreach(var user in data.Users)db.MemberAvailabilities.Add(new MemberAvailability{Id=Guid.NewGuid(),UserId=user,SeasonId=data.SeasonId,DayOfWeek=day.DayOfWeek,IsAvailable=true,Slots=[new(){Id=Guid.NewGuid(),StartMinute=480,EndMinute=1260}]});
        await db.SaveChangesAsync();
        await scope.ServiceProvider.GetRequiredService<IChatService>().GetHouseRoomAsync(data.HouseId,data.Users[0]);
        var context=await scope.ServiceProvider.GetRequiredService<IAIContextBuilder>().BuildAsync(data.HouseId,data.SeasonId,default);
        var tasks=await db.ChoreOccurrences.Include(o=>o.Chore).Where(o=>o.AssignedUserId!=data.Users[0]).OrderBy(o=>o.AssignedUserId).ToListAsync();
        return new ScheduleChangePayload{SeasonId=data.SeasonId,ContextHash=scope.ServiceProvider.GetRequiredService<IAIContextBuilder>().Fingerprint(context),Changes=tasks.Select((task,index)=>new ScheduleAssignment{OccurrenceId=task.Id,AssignedUserId=tasks[1-index].AssignedUserId!.Value,PlannedStartAt=task.PlannedStartAt!.Value,PreviousUserId=task.AssignedUserId!.Value,PreviousStartAt=task.PlannedStartAt,Name=task.Chore.Name}).ToList()};
    }

    [PostgresFact]
    public async Task ReplanWaitsForEveryAffectedMemberThenAppliesAtomically() {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f);var change=await PrepareReplan(f,data);
        Guid proposal;
        await using(var create=f.Services.CreateAsyncScope())proposal=(await create.ServiceProvider.GetRequiredService<IActionProposalService>().CreateProposalAsync(data.HouseId,new CreateProposalRequest{Type=ProposalType.SCHEDULE_REPLAN,Title="Review schedule change",PayloadJson=JsonSerializer.Serialize(change),TargetUserIds=data.Users.Skip(1).ToList(),ExpiresAt=DateTime.UtcNow.AddMinutes(10)},data.Users[0])).Id;
        await using(var first=f.Services.CreateAsyncScope()) {
            await first.ServiceProvider.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal,new RespondProposalRequest{Status=ConfirmationStatus.CONFIRMED},data.Users[1]);
            Assert.Equal(3,(await first.ServiceProvider.GetRequiredService<AppDbContext>().Seasons.SingleAsync()).ScheduleRevision);
        }
        await using(var last=f.Services.CreateAsyncScope())await last.ServiceProvider.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal,new RespondProposalRequest{Status=ConfirmationStatus.CONFIRMED},data.Users[2]);
        await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(4,(await db.Seasons.SingleAsync()).ScheduleRevision);
        foreach(var item in change.Changes)Assert.Equal(item.AssignedUserId,(await db.ChoreOccurrences.SingleAsync(o=>o.Id==item.OccurrenceId)).AssignedUserId);
        Assert.Equal(2,await db.Set<ChoreResponsibility>().CountAsync(r=>r.Reason=="REPLAN" && r.EndedAt==null));
    }

    [PostgresFact]
    public async Task TransferSnapshotAndTelemetryCommitAtomicallyAndPreserveOriginalContext()
    {
        await using var f=await Fixture();var data=await CoreConcurrencyTests.Seed(f);
        Guid snapshotId;
        await using(var scope=f.Services.CreateAsyncScope()) {
            var coordinator=scope.ServiceProvider.GetRequiredService<IHouseMutationCoordinator>();
            await coordinator.RunAsync(data.HouseId,async()=> {
                var uow=scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
                var occurrence=await uow.ChoreOccurrences.GetByIdAsync(data.OccurrenceId) ?? throw new Exception();
                await ChoreResponsibilityService.AssignAsync(uow,occurrence,data.Users[1],"BOUNTY",occurrence.DueDate,DateTime.UtcNow,default);
            });
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var snapshot=await db.AIResponsibilityContextSnapshots.SingleAsync();snapshotId=snapshot.Id;
            var payload=JsonDocument.Parse(snapshot.PayloadJson).RootElement;
            Assert.Equal(data.Users[1],payload.GetProperty("member_id").GetGuid());
            Assert.Contains(payload.GetProperty("workload").EnumerateArray(),t=>t.GetProperty("Id").GetGuid()==data.OccurrenceId);
            Assert.True(await db.OutboxMessages.AnyAsync(e=>e.Topic==AIConstants.TelemetryTopic));
        }
        await using(var scope=f.Services.CreateAsyncScope()) {
            var coordinator=scope.ServiceProvider.GetRequiredService<IHouseMutationCoordinator>();
            await Assert.ThrowsAsync<InvalidOperationException>(()=>coordinator.RunAsync(data.HouseId,async()=> {
                var uow=scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
                var occurrence=await uow.ChoreOccurrences.GetByIdAsync(data.OccurrenceId) ?? throw new Exception();
                await ChoreResponsibilityService.AssignAsync(uow,occurrence,data.Users[2],"SWAP",occurrence.DueDate,DateTime.UtcNow,default);
                await uow.SaveChangesAsync();
                throw new InvalidOperationException("Simulated rollback");
            }));
        }
        await using var read=f.Services.CreateAsyncScope();var state=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Single(await state.AIResponsibilityContextSnapshots.ToListAsync());
        Assert.Equal(snapshotId,(await state.AIResponsibilityContextSnapshots.SingleAsync()).Id);
        Assert.Equal(data.Users[1],(await state.ChoreOccurrences.SingleAsync()).AssignedUserId);
    }

    [PostgresFact]
    public async Task EvaluationOwnerScopeCheckedBeforeCallingPython()
    {
        var client=new Mock<IAIHousekeeperClient>();
        await using var f=await Fixture(s=>s.AddScoped(_=>client.Object));var data=await CoreConcurrencyTests.Seed(f);
        await using var scope=f.Services.CreateAsyncScope();var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.ReadAsync(data.HouseId,data.Users[1],"evaluations/runs",true,default));
        await Assert.ThrowsAsync<ForbiddenException>(()=>service.ReadAsync(Guid.NewGuid(),data.Users[0],"profiles",false,default));
        client.Verify(c=>c.GetAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),It.IsAny<string>(),It.IsAny<CancellationToken>()),Times.Never);
    }

    [PostgresFact]
    public async Task PreviewRetryDoesNotDuplicateInferenceAndStaleCannotApply()
    {
        var client=new Mock<IAIHousekeeperClient>();
        client.Setup(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/schedules/propose",It.IsAny<object>(),It.IsAny<CancellationToken>()))
            .ReturnsAsync(JsonSerializer.SerializeToElement(new{tasks=Array.Empty<object>(),reason="NO_MATERIAL_IMPROVEMENT"}));
        await using var f=await Fixture(s=>s.AddScoped(_=>client.Object));var data=await CoreConcurrencyTests.Seed(f,SeasonStatus.DRAFT);
        async Task<JsonElement> Generate(AIGenerateRequest request) { await using var scope=f.Services.CreateAsyncScope();return await scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>().GenerateAsync(data.HouseId,data.Users[0],request,default); }
        await using(var setup=f.Services.CreateAsyncScope()) await setup.ServiceProvider.GetRequiredService<IAIHousekeeperService>().SettingsAsync(data.HouseId,data.Users[0],true,false,default);
        var request=new AIGenerateRequest{ClientRequestId=Guid.NewGuid(),SeasonId=data.SeasonId};
        var first=await Generate(request);var again=await Generate(request);
        Assert.Equal(first.GetProperty("id").GetGuid(),again.GetProperty("id").GetGuid());
        client.Verify(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/schedules/propose",It.IsAny<object>(),It.IsAny<CancellationToken>()),Times.Once);
        await using(var change=f.Services.CreateAsyncScope()) {var db=change.ServiceProvider.GetRequiredService<AppDbContext>();(await db.Seasons.SingleAsync()).ScheduleRevision++;await db.SaveChangesAsync();}
        await using var accept=f.Services.CreateAsyncScope();
        await Assert.ThrowsAsync<ConflictException>(()=>accept.ServiceProvider.GetRequiredService<IAIHousekeeperService>().AcceptAsync(data.HouseId,data.Users[0],first.GetProperty("id").GetGuid(),default));
        Assert.Equal(ChoreOccurrenceStatus.ASSIGNED,(await accept.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync()).Status);
    }
}
