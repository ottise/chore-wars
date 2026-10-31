using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.AI;

public sealed class AIHousekeeperHttpClient(
    HttpClient http,
    IOptions<AIOptions> options,
    AppDbContext db,
    ILogger<AIHousekeeperHttpClient> logger) : IAIHousekeeperClient
{
    public Task<JsonElement> GetAsync(Guid houseId, Guid actorId, string path, CancellationToken ct)
        => SendAsync(houseId, actorId, HttpMethod.Get, path, null, ct);
    public Task<JsonElement> PostAsync(Guid houseId, Guid actorId, string path, object payload, CancellationToken ct)
        => SendAsync(houseId, actorId, HttpMethod.Post, path, payload, ct);

    private async Task<JsonElement> SendAsync(Guid house, Guid actor, HttpMethod method, string path, object? body, CancellationToken ct)
    {
        if (!options.Value.Enabled || options.Value.ServiceKey.Length < 32) throw new ConflictException("AI is not configured. Manual workflows remain available.");
        using var request = new HttpRequestMessage(method, path);
        request.Headers.Add("X-AI-Key", options.Value.ServiceKey);
        request.Headers.Add("X-House-Id", house.ToString());
        request.Headers.Add("X-Actor-Id", actor.ToString());
        var sequence=await db.Houses.AsNoTracking().Where(h=>h.Id==house).Select(h=>h.AiTelemetrySequence).SingleAsync(ct);
        request.Headers.Add("X-Core-Sequence",sequence.ToString(System.Globalization.CultureInfo.InvariantCulture));
        if (body != null) request.Content = JsonContent.Create(body);
        try
        {
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                var upstreamCode = await ReadErrorCodeAsync(response, ct);
                logger.LogWarning(
                    "AI service returned HTTP {StatusCode} for {Path}; upstream code: {UpstreamCode}",
                    (int)response.StatusCode,
                    path,
                    upstreamCode ?? "none");

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
