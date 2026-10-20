using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Diagnostics;
using ChoreWars.Infrastructure.Messaging.Kafka.Consumers;
using ChoreWars.Infrastructure.Workers;
using ChoreWars.Presentation.Extensions;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

// This executable belongs to the integration suite. No HTTP endpoints are exposed.
var builder=Host.CreateApplicationBuilder(args);
var connection=new NpgsqlConnectionStringBuilder(builder.Configuration.GetConnectionString("DefaultConnection"));
if(connection.Host is not ("127.0.0.1" or "localhost") || !connection.Database!.StartsWith("cw_test_",StringComparison.Ordinal))
    throw new InvalidOperationException("WorkerTestHost requires a disposable local cw_test_ database.");
builder.Services.AddInfrastructureServices(builder.Configuration);
builder.Services.AddApplicationServices();
builder.Services.RemoveAll<IHostedService>();
builder.Services.AddSingleton<INotificationRealtimePublisher,SilentRealtime>();
builder.Services.AddSingleton<IRuntimeProbe>(new FileGate(builder.Configuration["TEST_PROBE_POINT"]!,builder.Configuration["TEST_PROBE_ACK"]!));
var mode=builder.Configuration["TEST_WORKER_MODE"];
if(mode=="consumer") builder.Services.AddHostedService<BountyCreatedConsumer>();
else if(mode=="dispatcher") builder.Services.AddHostedService<OutboxDispatcherWorker>();
else if(mode!="mutation") throw new InvalidOperationException("Unknown test worker mode.");
using var host=builder.Build();
await host.StartAsync();
if(mode=="mutation") {
    await using var scope=host.Services.CreateAsyncScope();
    await scope.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(Guid.Parse(builder.Configuration["TEST_OCCURRENCE"]!),null,Guid.Parse(builder.Configuration["TEST_USER"]!));
    await host.StopAsync();
} else await host.WaitForShutdownAsync();

sealed class FileGate(string point,string acknowledgement) : IRuntimeProbe {
    public async Task HitAsync(string current,CancellationToken ct) {
        if(current!=point) return;
        await File.WriteAllTextAsync(acknowledgement,current,ct);
        await Task.Delay(Timeout.Infinite,ct);
    }
}
sealed class SilentRealtime : INotificationRealtimePublisher {
    public Task PublishAsync(NotificationResponse response,CancellationToken ct=default)=>Task.CompletedTask;
}
