using System.Text.Json;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;

namespace IntegrationTests.Infrastructure;

public class AIServiceContractTests
{
    private static async Task SyncEvents(PostgresFixture fixture,Guid house,Guid actor)
    {
        await using var scope=fixture.Services.CreateAsyncScope();
        var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var payloads=await db.OutboxMessages.Where(m=>m.Topic==AIConstants.TelemetryTopic).OrderBy(m=>m.CreatedAt).Select(m=>m.Payload).ToListAsync();
        var events=payloads.Select(p=>JsonSerializer.Deserialize<JsonElement>(p)).ToArray();
        var result=await scope.ServiceProvider.GetRequiredService<IAIHousekeeperClient>().PostAsync(house,actor,"/internal/events",events,default);
        Assert.InRange(result.GetProperty("new_events").GetInt32(),0,events.Length);
    }

    [AIPythonFact]
    public async Task ActualPythonRoundTripPreservesCoreReviewAndReportsObservedContribution()
    {
        var url=new Uri(Environment.GetEnvironmentVariable("CHOREWARS_TEST_AI_URL")!);
        Assert.Contains(url.Host,new[]{"localhost","127.0.0.1"});
        await using var fixture=await PostgresFixture.CreateAsync(new(){["AI:Enabled"]="true",["AI:BaseUrl"]=url.ToString(),["AI:ServiceKey"]=Environment.GetEnvironmentVariable("CHOREWARS_TEST_AI_KEY")},services=>{
            services.AddScoped(_=>Mock.Of<IActionProposalRealtimePublisher>());
            services.AddScoped(_=>Mock.Of<INotificationRealtimePublisher>());
        });
        var data=await CoreConcurrencyTests.Seed(fixture,SeasonStatus.DRAFT);
        await using(var scope=fixture.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var task=await db.ChoreOccurrences.SingleAsync();task.AssignedUserId=null;
            var day=DateOnly.FromDateTime(ScheduleTime.Local(DateTime.UtcNow)).AddDays(1);
            task.DueDate=ScheduleTime.Utc(day,1260);
            foreach(var member in data.Users)db.MemberAvailabilities.Add(new MemberAvailability{Id=Guid.NewGuid(),SeasonId=data.SeasonId,UserId=member,DayOfWeek=day.DayOfWeek,IsAvailable=true,Slots=[new(){Id=Guid.NewGuid(),StartMinute=480,EndMinute=1260}]});
            await db.SaveChangesAsync();
            await scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>().SettingsAsync(data.HouseId,data.Users[0],true,false,default);
        }
        await SyncEvents(fixture,data.HouseId,data.Users[0]);
        await using(var scope=fixture.Services.CreateAsyncScope()) {
            var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            var preview=await service.GenerateAsync(data.HouseId,data.Users[0],new AIGenerateRequest{ClientRequestId=Guid.NewGuid(),SeasonId=data.SeasonId},default);
            Assert.Equal("READY",preview.GetProperty("status").GetString());
            Assert.Equal(1,preview.GetProperty("result").GetProperty("metrics").GetProperty("coverage_count").GetInt32());
            await service.AcceptAsync(data.HouseId,data.Users[0],preview.GetProperty("id").GetGuid(),default);
            Assert.Equal(SeasonStatus.DRAFT,(await scope.ServiceProvider.GetRequiredService<AppDbContext>().Seasons.SingleAsync()).Status);
        }
        await SyncEvents(fixture,data.HouseId,data.Users[0]);
        await using(var scope=fixture.Services.CreateAsyncScope()) {
            var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            await service.EvaluateAsync(data.HouseId,data.Users[0],data.SeasonId,default);
            var runs=await service.ReadAsync(data.HouseId,data.Users[0],"evaluations/runs",true,default);
            Assert.Equal(3,runs.GetProperty("items").GetArrayLength());
            await scope.ServiceProvider.GetRequiredService<ISeasonService>().SubmitReviewAsync(data.SeasonId,data.Users[0]);
        }
        foreach(var user in data.Users) {
            await using var scope=fixture.Services.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(data.SeasonId,user,expectedRevision:4);
        }
        await using(var scope=fixture.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(SeasonStatus.ACTIVE,(await db.Seasons.SingleAsync()).Status);
            var task=await db.ChoreOccurrences.SingleAsync();
            await scope.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(task.Id,null,task.AssignedUserId!.Value);
        }
        await SyncEvents(fixture,data.HouseId,data.Users[0]);
        await using var read=fixture.Services.CreateAsyncScope();
        var profile=await read.ServiceProvider.GetRequiredService<IAIHousekeeperService>().ReadAsync(data.HouseId,data.Users[0],"profiles",false,default);
        Assert.True(profile.GetProperty("telemetry_complete").GetBoolean());
        Assert.Equal(1,profile.GetProperty("items").EnumerateArray().Sum(p=>p.GetProperty("completed_count").GetInt32()));
        Assert.Equal(30,profile.GetProperty("items").EnumerateArray().Sum(p=>p.GetProperty("standard_minutes").GetInt32()));
        Assert.Single(await read.ServiceProvider.GetRequiredService<AppDbContext>().AIResponsibilityContextSnapshots.ToListAsync());
    }
}
