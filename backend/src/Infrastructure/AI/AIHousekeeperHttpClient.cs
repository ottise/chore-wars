using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Options;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.AI;

public sealed class AIHousekeeperHttpClient(HttpClient http, IOptions<AIOptions> options, AppDbContext db) : IAIHousekeeperClient
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
        using var response = await http.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode) throw new ConflictException($"AI request failed ({(int)response.StatusCode}). No business changes were applied.");
        return await response.Content.ReadFromJsonAsync<JsonElement>(ct);
    }
}
