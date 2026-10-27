using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.DTOs.Deployment;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.AI;
using ChoreWars.Infrastructure.Messaging.Kafka;
using Confluent.Kafka;
using Microsoft.Extensions.Options;
using StackExchange.Redis;

namespace ChoreWars.Infrastructure.Diagnostics;

public sealed class DependencyHealthService(IDatabaseSchemaStatus schema, IOptions<KafkaOptions> kafka,
    IConnectionMultiplexer redis, IOptions<AIOptions> ai, IHttpClientFactory clients,
    IWorkerHealthRegistry workers, TimeProvider clock) : IDependencyHealthService
{
    private static readonly TimeSpan ProbeTimeout = TimeSpan.FromSeconds(2);
    public async Task<IReadOnlyList<DependencyStatusResponse>> CheckAsync(CancellationToken ct = default)
    {
        var database = await schema.CheckAsync(ct);
        var result = new List<DependencyStatusResponse> { new("database", database.Ready ? "pass" : "fail", database.ReasonCode, clock.GetUtcNow()) };
        try
        {
            using var admin = new AdminClientBuilder(kafka.Value.ConnectionConfig()).Build();
            var metadata = await Task.Run(() => admin.GetMetadata(ProbeTimeout), ct);
            var topics = metadata.Topics.Where(x => !x.Error.IsError).Select(x => x.Topic).ToHashSet();
            var required = KafkaTopics.EventTopicMap.Values.Append("ai.telemetry.v1").Select(x => kafka.Value.TopicPrefix + x);
            result.Add(new("kafka", required.All(topics.Contains) ? "pass" : "fail", "broker_metadata_and_topics", clock.GetUtcNow()));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { result.Add(new("kafka", "fail", "broker_probe_failed", clock.GetUtcNow())); }
        try
        {
            await redis.GetDatabase().PingAsync().WaitAsync(ProbeTimeout, ct);
            result.Add(new("redis", "pass", "cache_reachable", clock.GetUtcNow()));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { result.Add(new("redis", "degraded", "cache_fallback_available", clock.GetUtcNow())); }
        if (!ai.Value.Enabled) result.Add(new("ai", "not-applicable", "disabled", clock.GetUtcNow()));
        else
        {
            try
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeout.CancelAfter(ProbeTimeout);
                using var request = new HttpRequestMessage(HttpMethod.Get, new Uri(new Uri(ai.Value.BaseUrl.TrimEnd('/') + "/"), "health/service-auth"));
                request.Headers.Add("X-AI-Key", ai.Value.ServiceKey);
                using var response = await clients.CreateClient().SendAsync(request, timeout.Token);
                var data = response.IsSuccessStatusCode ? await response.Content.ReadFromJsonAsync<JsonElement>(timeout.Token) : default;
                var ready = response.IsSuccessStatusCode && data.ValueKind == JsonValueKind.Object && data.TryGetProperty("authenticated", out var auth) && auth.GetBoolean()
                    && data.TryGetProperty("schema_ready", out var aiSchema) && aiSchema.GetBoolean()
                    && data.TryGetProperty("provider_configured", out var provider) && provider.GetBoolean();
                result.Add(new("ai", ready ? "pass" : "fail", "service_auth_and_schema", clock.GetUtcNow()));
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch (Exception) { result.Add(new("ai", "fail", "ai_probe_failed", clock.GetUtcNow())); }
        }
        var snapshot = workers.Snapshot();
        result.AddRange(snapshot);
        foreach (var name in KafkaTopics.EventTopicMap.Values.Append("outbox"))
            if (!snapshot.Any(x => x.Name == "worker:" + name))
                result.Add(new("worker:" + name, "unverified", "no_heartbeat", clock.GetUtcNow()));
        result.Add(new("media", "unverified", "durable_storage_not_verified", clock.GetUtcNow()));
        return result;
    }
}
