using System.Diagnostics;
using System.Text.Json;
using ChoreWars.Application.DTOs.Bounty;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Diagnostics;
using ChoreWars.Infrastructure.Messaging.Kafka;
using ChoreWars.Infrastructure.Messaging.Kafka.Consumers;
using ChoreWars.Infrastructure.Workers;
using Confluent.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace IntegrationTests.Infrastructure;

public sealed class KafkaFactAttribute : FactAttribute
{
    public KafkaFactAttribute() { if(string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_KAFKA")) || string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_POSTGRES"))) Skip="Run test-runtime.ps1 with disposable PostgreSQL/Kafka."; }
}
[CollectionDefinition("Kafka runtime",DisableParallelization=true)] public class KafkaRuntimeCollection { }
[Collection("Kafka runtime")]
public class RealKafkaTests
{
    private sealed class SilentRealtime : INotificationRealtimePublisher {
        public Task PublishAsync(NotificationResponse notification,CancellationToken ct=default)=>Task.CompletedTask;
    }
    private sealed class OneShotFault(string point) : IRuntimeProbe {
        public int Hits;
        public Task HitAsync(string current,CancellationToken ct) {
            if(current==point && Interlocked.Increment(ref Hits)==1) throw new IOException("Controlled runtime test fault at "+point);
            return Task.CompletedTask;
        }
    }
    private static KafkaOptions OptionsFor(string group)=>new() { BootstrapServers=Environment.GetEnvironmentVariable("CHOREWARS_TEST_KAFKA")!, ConsumerGroupId=group, TopicPrefix=group+".", SessionTimeoutMs=6000 };
    private static async Task<PostgresFixture> Fixture(KafkaOptions options, IRuntimeProbe? probe=null) => await PostgresFixture.CreateAsync(
        new() { ["Kafka:BootstrapServers"]=options.BootstrapServers,["Kafka:ConsumerGroupId"]=options.ConsumerGroupId,["Kafka:TopicPrefix"]=options.TopicPrefix,["Kafka:SessionTimeoutMs"]=options.SessionTimeoutMs.ToString() },
        services=> { services.AddSingleton<INotificationRealtimePublisher,SilentRealtime>();if(probe!=null)services.AddSingleton(probe); });
    private static async Task Until(Func<Task<bool>> condition,int seconds=60) {
        var timeout=DateTime.UtcNow.AddSeconds(seconds);
        while(DateTime.UtcNow<timeout) { if(await condition())return;await Task.Delay(150); }
        throw new TimeoutException("Expected Kafka/DB condition did not become true.");
    }
    private static async Task<int> Count(PostgresFixture f,string kind,string? key=null) {
        await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return kind switch {
            "notifications"=>await db.Notifications.CountAsync(),
            "processed"=>await db.ProcessedMessages.CountAsync(x=>x.Id==key),
            "failed"=>await db.FailedEvents.CountAsync(),
            "resolved"=>await db.FailedEvents.CountAsync(x=>x.Status=="RESOLVED"),
            "published"=>await db.OutboxMessages.CountAsync(x=>x.PublishedAt!=null),
            _=>throw new ArgumentException(kind)
        };
    }
    private static async Task<Guid> Bounty(PostgresFixture f,CoreConcurrencyTests.Data seed) {
        await using var scope=f.Services.CreateAsyncScope();
        return (await scope.ServiceProvider.GetRequiredService<IBountyService>().CreateBountyAsync(seed.HouseId,new CreateBountyRequest { ChoreOccurrenceId=seed.OccurrenceId,Amount=10000 },seed.Users[0])).Id;
    }
    private static IProducer<string,string> Producer(KafkaOptions options)=>new ProducerBuilder<string,string>(new ProducerConfig { BootstrapServers=options.BootstrapServers,MessageTimeoutMs=10000 }).Build();
    private static async Task Publish(IProducer<string,string> producer,KafkaOptions options,string key,string payload) =>
        await producer.ProduceAsync(new TopicPartition(options.TopicPrefix+KafkaTopics.BOUNTY_CREATED,new Partition(0)),new Message<string,string>{Key=key,Value=payload});
    private static BountyCreatedConsumer Consumer(PostgresFixture f,KafkaOptions options)=>new(Microsoft.Extensions.Options.Options.Create(options),f.Services.GetRequiredService<IServiceScopeFactory>(),NullLogger<BountyCreatedConsumer>.Instance);
    private static OutboxDispatcherWorker Dispatcher(PostgresFixture f,KafkaOptions options)=>new(f.Services.GetRequiredService<IServiceScopeFactory>(),Microsoft.Extensions.Options.Options.Create(options),NullLogger<OutboxDispatcherWorker>.Instance);

    [KafkaFact] public async Task PoisonIsDurablyIsolatedAndFollowingMessageIsProcessed() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));
        await using var f=await Fixture(options);var seed=await CoreConcurrencyTests.Seed(f);var bounty=await Bounty(f,seed);
        using var producer=Producer(options);
        var poison=Guid.NewGuid().ToString();var marker=Guid.NewGuid().ToString();
        await Publish(producer,options,poison,"{invalid-json");
        await Publish(producer,options,marker,JsonSerializer.Serialize(new BountyCreatedEvent(bounty,seed.HouseId)));
        using var consumer=Consumer(f,options);await consumer.StartAsync(default);
        try {
            await Until(async()=>await Count(f,"processed",marker)==1);
            Assert.Equal(1,await Count(f,"failed"));Assert.Equal(3,await Count(f,"notifications"));
            await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var failed=await db.FailedEvents.SingleAsync();Assert.Equal(poison,failed.EventKey);Assert.Null(failed.HouseId);Assert.Equal("{invalid-json",failed.Payload);
            var list=await scope.ServiceProvider.GetRequiredService<IFailedEventService>().ListAsync(seed.HouseId,seed.Users[0],null,1,default);Assert.Empty(list.Items);
        } finally { await consumer.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }

    [KafkaFact] public async Task DuplicateDeliveryAfterConsumerRestartDoesNotRepeatSideEffects() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));
        await using var f=await Fixture(options);var seed=await CoreConcurrencyTests.Seed(f);var bounty=await Bounty(f,seed);
        var key=Guid.NewGuid().ToString();var payload=JsonSerializer.Serialize(new BountyCreatedEvent(bounty,seed.HouseId));
        using var producer=Producer(options);using(var first=Consumer(f,options)) {
            await first.StartAsync(default);await Publish(producer,options,key,payload);await Until(async()=>await Count(f,"processed",key)==1);await first.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token);
        }
        using var restarted=Consumer(f,options);await restarted.StartAsync(default);
        try {
            await Publish(producer,options,key,payload);var barrier=Guid.NewGuid().ToString();await Publish(producer,options,barrier,payload);
            await Until(async()=>await Count(f,"processed",barrier)==1);
            Assert.Equal(1,await Count(f,"processed",key));Assert.Equal(6,await Count(f,"notifications"));
        } finally { await restarted.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }

    [KafkaFact] public async Task BrokerAckBeforeOutboxCommitCanRedeliverWithoutDuplicatingNotification() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));var fault=new OneShotFault("outbox.after-publish");
        await using var f=await Fixture(options,fault);var seed=await CoreConcurrencyTests.Seed(f);await Bounty(f,seed);
        using var consumer=Consumer(f,options);using var dispatcher=Dispatcher(f,options);
        await consumer.StartAsync(default);await dispatcher.StartAsync(default);
        try {
            await Until(async()=>await Count(f,"published")==1);
            Assert.True(fault.Hits>=2);await Until(async()=>await Count(f,"notifications")==3);
            await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var outbox=await db.OutboxMessages.SingleAsync();Assert.Equal(1,await Count(f,"processed",outbox.Id.ToString()));
        } finally { await dispatcher.StopAsync(default);await consumer.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }

    [KafkaFact] public async Task CommittedConsumerDataSurvivesOffsetRetryWithoutRepeatingSideEffects() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));var fault=new OneShotFault("consumer.after-commit");
        await using var f=await Fixture(options,fault);var seed=await CoreConcurrencyTests.Seed(f);var bounty=await Bounty(f,seed);
        using var producer=Producer(options);using var consumer=Consumer(f,options);await consumer.StartAsync(default);
        try {
            var key=Guid.NewGuid().ToString();await Publish(producer,options,key,JsonSerializer.Serialize(new BountyCreatedEvent(bounty,seed.HouseId)));
            await Until(async()=>fault.Hits>=2 && await Count(f,"processed",key)==1);
            Assert.Equal(3,await Count(f,"notifications"));Assert.Equal(0,await Count(f,"failed"));
        } finally { await consumer.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }
    [KafkaFact] public async Task HardCrashAfterBrokerAckRetainsOutboxAndReplayIsDeduplicated() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));
        await using var f=await Fixture(options);var seed=await CoreConcurrencyTests.Seed(f);var bounty=await Bounty(f,seed);
        using var consumer=Consumer(f,options);await consumer.StartAsync(default);
        try {
            await using(var child=WorkerProcessHarness.Start(f,"dispatcher","outbox.after-publish",options)) {
                await child.WaitForProbeAsync();await child.KillAsync();
            }
            Assert.Equal(0,await Count(f,"published"));
            using var restarted=Dispatcher(f,options);await restarted.StartAsync(default);
            try {
                await Until(async()=>await Count(f,"published")==1);
                using var producer=Producer(options);var barrier=Guid.NewGuid().ToString();
                await Publish(producer,options,barrier,JsonSerializer.Serialize(new BountyCreatedEvent(bounty,seed.HouseId)));
                await Until(async()=>await Count(f,"processed",barrier)==1);
                Assert.Equal(6,await Count(f,"notifications"));
            } finally { await restarted.StopAsync(default); }
        } finally { await consumer.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }

    [KafkaFact] public async Task HardConsumerCrashAfterDatabaseCommitReplaysWithoutDuplicateEffects() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));
        await using var f=await Fixture(options);var seed=await CoreConcurrencyTests.Seed(f);var bounty=await Bounty(f,seed);
        var key=Guid.NewGuid().ToString();var payload=JsonSerializer.Serialize(new BountyCreatedEvent(bounty,seed.HouseId));
        using var producer=Producer(options);
        await using(var child=WorkerProcessHarness.Start(f,"consumer","consumer.after-commit",options)) {
            await Publish(producer,options,key,payload);await child.WaitForProbeAsync();
            Assert.Equal(1,await Count(f,"processed",key));await child.KillAsync();
        }
        using var restarted=Consumer(f,options);await restarted.StartAsync(default);
        try {
            var barrier=Guid.NewGuid().ToString();await Publish(producer,options,barrier,payload);
            await Until(async()=>await Count(f,"processed",barrier)==1);
            Assert.Equal(6,await Count(f,"notifications"));Assert.Equal(1,await Count(f,"processed",key));
        } finally { await restarted.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }

    [KafkaFact] public async Task HardConsumerCrashBeforeDatabaseCommitRollsBackThenRetries() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));
        await using var f=await Fixture(options);var seed=await CoreConcurrencyTests.Seed(f);var bounty=await Bounty(f,seed);
        var key=Guid.NewGuid().ToString();var payload=JsonSerializer.Serialize(new BountyCreatedEvent(bounty,seed.HouseId));
        using var producer=Producer(options);
        await using(var child=WorkerProcessHarness.Start(f,"consumer","consumer.before-commit",options)) {
            await Publish(producer,options,key,payload);await child.WaitForProbeAsync();await child.KillAsync();
        }
        Assert.Equal(0,await Count(f,"processed",key));Assert.Equal(0,await Count(f,"notifications"));
        using var restarted=Consumer(f,options);await restarted.StartAsync(default);
        try { await Until(async()=>await Count(f,"processed",key)==1);Assert.Equal(3,await Count(f,"notifications")); }
        finally { await restarted.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }
    private sealed class ToggleFault : IRuntimeProbe {
        public volatile bool Enabled=true;
        public Task HitAsync(string point,CancellationToken ct) {
            if(Enabled && point=="consumer.before-commit") throw new IOException("Controlled temporary handler failure");
            return Task.CompletedTask;
        }
    }
    [KafkaFact] public async Task HouseOwnerCanReplayQuarantinedEventAndObserveResolution() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));var fault=new ToggleFault();
        await using var f=await Fixture(options,fault);var seed=await CoreConcurrencyTests.Seed(f);await Bounty(f,seed);
        string key,payload;
        await using(var scope=f.Services.CreateAsyncScope()) { var item=await scope.ServiceProvider.GetRequiredService<AppDbContext>().OutboxMessages.SingleAsync();key=item.Id.ToString();payload=item.Payload; }
        using var producer=Producer(options);using var consumer=Consumer(f,options);await consumer.StartAsync(default);
        try {
            await Publish(producer,options,key,payload);await Until(async()=>await Count(f,"failed")==1);
            Assert.Equal(0,await Count(f,"notifications"));fault.Enabled=false;
            await using(var scope=f.Services.CreateAsyncScope()) {
                var service=scope.ServiceProvider.GetRequiredService<IFailedEventService>();
                var failed=Assert.Single((await service.ListAsync(seed.HouseId,seed.Users[0],"FAILED",1,default)).Items);
                await service.ReplayAsync(seed.HouseId,failed.Id,seed.Users[0],default);
            }
            using var dispatcher=Dispatcher(f,options);await dispatcher.StartAsync(default);
            try {
                await Until(async()=>await Count(f,"resolved")==1 && await Count(f,"published")==2);
                var barrier=Guid.NewGuid().ToString();await Publish(producer,options,barrier,payload);
                await Until(async()=>await Count(f,"processed",barrier)==1);
                Assert.Equal(6,await Count(f,"notifications"));Assert.Equal(1,await Count(f,"processed",key));
                await using var scope=f.Services.CreateAsyncScope();Assert.Equal(1,await scope.ServiceProvider.GetRequiredService<AppDbContext>().FailedEventReplays.CountAsync());
            } finally { await dispatcher.StopAsync(default); }
        } finally { await consumer.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); }
    }
    private sealed class DispatchFailureSignal : IRuntimeProbe {
        public readonly TaskCompletionSource Failed=new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task HitAsync(string point,CancellationToken ct) { if(point=="outbox.dispatch-failed")Failed.TrySetResult();return Task.CompletedTask; }
    }
    private static async Task BrokerCommand(string action) {
        var name=Environment.GetEnvironmentVariable("CHOREWARS_TEST_KAFKA_CONTAINER")??"";
        if(!System.Text.RegularExpressions.Regex.IsMatch(name,"^cw-runtime-kafka-[a-f0-9]{32}$")) throw new InvalidOperationException("Outage test requires its own runner-created broker.");
        var info=new ProcessStartInfo("docker") {UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,RedirectStandardOutput=true,RedirectStandardError=true};
        info.ArgumentList.Add(action);info.ArgumentList.Add(name);
        using var process=Process.Start(info)??throw new InvalidOperationException("Could not control disposable broker.");
        var stdout=process.StandardOutput.ReadToEndAsync();var stderr=process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(20));
        if(process.ExitCode!=0)throw new InvalidOperationException(await stderr+await stdout);
    }
    [KafkaFact] public async Task BrokerOutageRetainsPendingOutboxAndDrainsWhenBrokerReturns() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));var signal=new DispatchFailureSignal();
        await using var f=await Fixture(options,signal);var seed=await CoreConcurrencyTests.Seed(f);await Bounty(f,seed);
        using var consumer=Consumer(f,options);using var dispatcher=Dispatcher(f,options);
        await consumer.StartAsync(default);
        var paused=false;
        try {
            await BrokerCommand("pause");paused=true;await dispatcher.StartAsync(default);
            await signal.Failed.Task.WaitAsync(TimeSpan.FromSeconds(40));Assert.Equal(0,await Count(f,"published"));
            await BrokerCommand("unpause");paused=false;
            await Until(async()=>await Count(f,"published")==1 && await Count(f,"notifications")==3);
        } finally {
            if(paused)await BrokerCommand("unpause");
            await dispatcher.StopAsync(default);await consumer.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token);
        }
    }
    [KafkaFact] public async Task CompletionAndAcceptanceAwardHouseScopedAchievementsThroughRealConsumers() {
        var options=OptionsFor("cw-test-"+Guid.NewGuid().ToString("N"));
        await using var f=await Fixture(options);var seed=await CoreConcurrencyTests.Seed(f);var help=Guid.NewGuid();
        await using(var scope=f.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Achievements.AddRange(ChoreWars.Application.Services.AchievementDefaults.ForHouse(seed.HouseId));
            var occurrence=await db.ChoreOccurrences.SingleAsync(x=>x.Id==seed.OccurrenceId);
            occurrence.SnapshotKarma=100;
            db.ChoreOccurrences.Add(new ChoreWars.Domain.Entities.ChoreOccurrence {Id=help,ChoreId=occurrence.ChoreId,SeasonId=seed.SeasonId,AssignedUserId=seed.Users[0],DueDate=DateTime.UtcNow.AddHours(2),SnapshotKarma=10,SnapshotMinutes=30});
            await db.SaveChangesAsync();
        }
        await using(var scope=f.Services.CreateAsyncScope()) await scope.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(seed.OccurrenceId,null,seed.Users[0]);
        Guid bounty;
        await using(var scope=f.Services.CreateAsyncScope()) {
            var service=scope.ServiceProvider.GetRequiredService<IBountyService>();
            bounty=(await service.CreateBountyAsync(seed.HouseId,new CreateBountyRequest{ChoreOccurrenceId=help,Amount=10000},seed.Users[0])).Id;
            await service.AcceptBountyAsync(bounty,seed.Users[1]);
        }
        var scopes=f.Services.GetRequiredService<IServiceScopeFactory>();
        using var completed=new ChoreCompletedConsumer(Microsoft.Extensions.Options.Options.Create(options),scopes,NullLogger<ChoreCompletedConsumer>.Instance);
        using var accepted=new BountyAcceptedConsumer(Microsoft.Extensions.Options.Options.Create(options),scopes,NullLogger<BountyAcceptedConsumer>.Instance);
        using var dispatcher=Dispatcher(f,options);
        await completed.StartAsync(default);await accepted.StartAsync(default);await dispatcher.StartAsync(default);
        try {
            await Until(async()=> {await using var scope=f.Services.CreateAsyncScope();return await scope.ServiceProvider.GetRequiredService<AppDbContext>().UserAchievements.CountAsync()==3;});
            await using(var scope=f.Services.CreateAsyncScope()) {
                var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
                Assert.Equal(2,await db.UserAchievements.CountAsync(x=>x.UserId==seed.Users[0]));
                Assert.Equal(1,await db.UserAchievements.CountAsync(x=>x.UserId==seed.Users[1]));
            }
            using var producer=Producer(options);
            await producer.ProduceAsync(options.TopicPrefix+KafkaTopics.BOUNTY_ACCEPTED,new Message<string,string>{Key=Guid.NewGuid().ToString(),Value=JsonSerializer.Serialize(new BountyAcceptedEvent(bounty,seed.Users[0]))});
            await Until(async()=>await Count(f,"failed")==1);
            await using var read=f.Services.CreateAsyncScope();var readDb=read.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(3,await readDb.UserAchievements.CountAsync());
            Assert.Equal(seed.HouseId,(await readDb.FailedEvents.SingleAsync()).HouseId);
        } finally {await dispatcher.StopAsync(default);await completed.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token);await accepted.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token);}
    }
}
