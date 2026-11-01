using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using System.Net;

namespace ChoreWars.Infrastructure.AI;

public sealed class AIHousekeeperHttpClient(
    HttpClient http,
    IOptions<AIOptions> options,
    AppDbContext db,
    ILogger<AIHousekeeperHttpClient> logger) : IAIHousekeeperClient
{
    private static readonly TimeSpan StartupWaitLimit = TimeSpan.FromSeconds(65);
    private static readonly TimeSpan ReadinessProbeTimeout = TimeSpan.FromSeconds(3);
    private static readonly TimeSpan ReadinessProbeInterval = TimeSpan.FromSeconds(2);

    public Task<JsonElement> GetAsync(Guid houseId, Guid actorId, string path, CancellationToken ct)
        => SendAsync(houseId, actorId, HttpMethod.Get, path, null, ct);
    public Task<JsonElement> PostAsync(Guid houseId, Guid actorId, string path, object payload, CancellationToken ct)
        => SendAsync(houseId, actorId, HttpMethod.Post, path, payload, ct);

    private async Task<JsonElement> SendAsync(Guid house, Guid actor, HttpMethod method, string path, object? body, CancellationToken ct)
    {
        if (!options.Value.Enabled || options.Value.ServiceKey.Length < 32) throw new ConflictException("AI is not configured. Manual workflows remain available.");
        var sequence=await db.Houses.AsNoTracking().Where(h=>h.Id==house).Select(h=>h.AiTelemetrySequence).SingleAsync(ct);
        try
        {
            using var response = await SendRequestAsync(method, path, body, house, actor, sequence, ct);
            if (!response.IsSuccessStatusCode)
            {
                var upstreamCode = await ReadErrorCodeAsync(response, ct);
                logger.LogWarning(
                    "AI service returned HTTP {StatusCode} for {Path}; upstream code: {UpstreamCode}",
                    (int)response.StatusCode,
                    path,
                    upstreamCode ?? "none");

                if (IsTransientGatewayResponse(response.StatusCode, upstreamCode) && IsSafeToRetry(method, path))
                {
                    logger.LogInformation("AI upstream is not ready for {Path}; waiting briefly for readiness before one retry", path);
                    if (await WaitUntilReadyAsync(ct))
                    {
                        using var retry = await SendRequestAsync(method, path, body, house, actor, sequence, ct);
                        if (retry.IsSuccessStatusCode)
                            return await retry.Content.ReadFromJsonAsync<JsonElement>(ct);

                        var retryCode = await ReadErrorCodeAsync(retry, ct);
                        logger.LogWarning("AI retry returned HTTP {StatusCode} for {Path}; upstream code: {UpstreamCode}",
                            (int)retry.StatusCode, path, retryCode ?? "none");
                    }
                }

                if ((int)response.StatusCode >= 500 || response.StatusCode == System.Net.HttpStatusCode.RequestTimeout)
                    throw new ServiceUnavailableException("The assistant is temporarily unavailable. Please try again shortly. No changes were made.");

                var message = "The assistant could not process this request. Please try again. No changes were made.";
                if (response.StatusCode is System.Net.HttpStatusCode.Unauthorized or System.Net.HttpStatusCode.Forbidden)
                    message = "The assistant connection needs attention. Please try again later. No changes were made.";
                throw new ConflictException(message);
            }
            return await response.Content.ReadFromJsonAsync<JsonElement>(ct);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        { throw new ServiceUnavailableException("The assistant is taking longer to start. Please try again shortly. No changes were made."); }
        catch (HttpRequestException)
        { throw new ServiceUnavailableException("The assistant could not be reached. Please try again shortly. No changes were made."); }
    }

    private async Task<HttpResponseMessage> SendRequestAsync(
        HttpMethod method, string path, object? body, Guid house, Guid actor, long sequence, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(method, path);
        request.Headers.Add("X-AI-Key", options.Value.ServiceKey);
        request.Headers.Add("X-House-Id", house.ToString());
        request.Headers.Add("X-Actor-Id", actor.ToString());
        request.Headers.Add("X-Core-Sequence", sequence.ToString(System.Globalization.CultureInfo.InvariantCulture));
        if (body != null) request.Content = JsonContent.Create(body);
        return await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
    }

    private async Task<bool> WaitUntilReadyAsync(CancellationToken ct)
    {
        var started = System.Diagnostics.Stopwatch.StartNew();
        while (started.Elapsed < StartupWaitLimit)
        {
            ct.ThrowIfCancellationRequested();
            using var probeTimeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            probeTimeout.CancelAfter(ReadinessProbeTimeout);
            try
            {
                using var probe = new HttpRequestMessage(HttpMethod.Get, "/health/ready");
                using var response = await http.SendAsync(probe, HttpCompletionOption.ResponseHeadersRead, probeTimeout.Token);
                if (response.IsSuccessStatusCode)
                {
                    logger.LogInformation("AI service became ready after {ElapsedSeconds}s; retrying the original request",
                        Math.Round(started.Elapsed.TotalSeconds, 1));
                    return true;
                }
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                // A cold or still-starting Render instance can time out while accepting the probe.
            }
            catch (HttpRequestException)
            {
                // Keep polling while the upstream is unavailable; never log upstream response content.
            }

            var remaining = StartupWaitLimit - started.Elapsed;
            if (remaining <= TimeSpan.Zero) break;
            await Task.Delay(remaining < ReadinessProbeInterval ? remaining : ReadinessProbeInterval, ct);
        }

        logger.LogWarning("AI service did not become ready within {WaitSeconds}s", StartupWaitLimit.TotalSeconds);
        return false;
    }

    private static bool IsTransientGatewayResponse(HttpStatusCode status, string? upstreamCode)
        => status is HttpStatusCode.BadGateway or HttpStatusCode.GatewayTimeout
            || (status == HttpStatusCode.ServiceUnavailable && upstreamCode is null);

    private static bool IsSafeToRetry(HttpMethod method, string path)
    {
        if (method == HttpMethod.Get) return true;
        // AI computation endpoints do not persist changes. Keep event ingestion/evaluation writes out of retries.
        return method == HttpMethod.Post
            && path.StartsWith("/v1/", StringComparison.Ordinal)
            && !path.StartsWith("/v1/events", StringComparison.Ordinal);
    }

    private static async Task<string?> ReadErrorCodeAsync(HttpResponseMessage response, CancellationToken ct)
    {
        try
        {
            await using var stream = await response.Content.ReadAsStreamAsync(ct);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
            if (document.RootElement.TryGetProperty("code", out var code) && code.ValueKind == JsonValueKind.String)
                return code.GetString() is { Length: <= 120 } value ? value : "code_too_long";
        }
        catch (JsonException)
        {
            // Do not log raw upstream response bodies; they may contain user data.
        }
        catch (NotSupportedException)
        {
            // The upstream response did not use JSON.
        }
        return null;
    }
}
