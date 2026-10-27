using System.Collections.Concurrent;
using ChoreWars.Application.DTOs.Deployment;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Infrastructure.Diagnostics;

public sealed class WorkerHealthRegistry(TimeProvider clock) : IWorkerHealthRegistry
{
    private static readonly TimeSpan MaximumAge = TimeSpan.FromSeconds(30);
    private readonly ConcurrentDictionary<string, DateTimeOffset> _heartbeats = new();
    public void Heartbeat(string name) => _heartbeats[name] = clock.GetUtcNow();
    public void Stopped(string name) => _heartbeats.TryRemove(name, out _);
    public IReadOnlyList<DependencyStatusResponse> Snapshot() => _heartbeats.OrderBy(x => x.Key)
        .Select(x => new DependencyStatusResponse("worker:" + x.Key,
            clock.GetUtcNow() - x.Value < MaximumAge ? "pass" : "fail", "loop_heartbeat", x.Value)).ToArray();
}
