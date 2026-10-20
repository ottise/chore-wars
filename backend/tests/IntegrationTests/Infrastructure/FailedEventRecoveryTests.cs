using System.Text.Json;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using ChoreWars.Infrastructure.Messaging.Recovery;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class FailedEventRecoveryTests
{
    [PostgresFact]
    public async Task OwnerReplayIsScopedAuditedAndIdempotent()
    {
        await using var f=await PostgresFixture.CreateAsync();
        var seed=await CoreConcurrencyTests.Seed(f);
        var other=await CoreConcurrencyTests.Seed(f);
        var payload=JsonSerializer.Serialize(new ChoreCompletedEvent(seed.OccurrenceId,seed.Users[0],seed.HouseId));
        Guid failedId;
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await FailedEventStore.CaptureAsync(db,"chore-wars-group",KafkaTopics.CHORE_COMPLETED,"stable-key",payload,0,5,new InvalidOperationException(),default);
            failedId=(await db.FailedEvents.SingleAsync()).Id;
        }
        async Task Replay(Guid house,Guid user) {
            await using var scope=f.Services.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<IFailedEventService>().ReplayAsync(house,failedId,user,default);
        }
        await Assert.ThrowsAsync<ForbiddenException>(()=>Replay(seed.HouseId,seed.Users[1]));
        await Assert.ThrowsAsync<NotFoundException>(()=>Replay(other.HouseId,other.Users[0]));
        await Task.WhenAll(Replay(seed.HouseId,seed.Users[0]),Replay(seed.HouseId,seed.Users[0]));
        await using var read=f.Services.CreateAsyncScope();
        var readDb=read.ServiceProvider.GetRequiredService<AppDbContext>();
        var message=Assert.Single(await readDb.OutboxMessages.ToListAsync());
        Assert.Equal("stable-key",message.MessageKey);Assert.Equal(payload,message.Payload);
        var audit=Assert.Single(await readDb.FailedEventReplays.ToListAsync());
        Assert.Equal(seed.Users[0],audit.RequestedByUserId);Assert.Equal(message.Id,audit.OutboxId);
        Assert.Equal("REPLAY_REQUESTED",(await readDb.FailedEvents.SingleAsync()).Status);
        var list=await read.ServiceProvider.GetRequiredService<IFailedEventService>().ListAsync(seed.HouseId,seed.Users[0],null,1,default);
        Assert.Equal(1,list.Total);Assert.Equal(1,list.Items[0].ReplayCount);
    }

    [PostgresFact]
    public async Task InvalidOrForgedHouseCannotExposeQuarantinedPayloadToAnOwner()
    {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var forged=JsonSerializer.Serialize(new ChoreCompletedEvent(seed.OccurrenceId,seed.Users[0],Guid.NewGuid()));
        Assert.Null(await EventScopeResolver.ResolveAsync(db,KafkaTopics.CHORE_COMPLETED,forged,default));
        foreach(var payload in new[]{"{invalid", "null",forged})
            await FailedEventStore.CaptureAsync(db,"chore-wars-group",KafkaTopics.CHORE_COMPLETED,Guid.NewGuid().ToString(),payload,0,1,new JsonException(),default);
        var list=await scope.ServiceProvider.GetRequiredService<IFailedEventService>().ListAsync(seed.HouseId,seed.Users[0],null,1,default);
        Assert.Equal(0,list.Total);Assert.Equal(3,await db.FailedEvents.CountAsync());
        Assert.All(await db.FailedEvents.ToListAsync(),x=>Assert.Null(x.HouseId));
    }
}
