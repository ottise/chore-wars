using System.Text.Json;

namespace ChoreWars.Application.Interfaces.Services;

public interface IAIContextBuilder
{
    Task<JsonElement> BuildAsync(Guid houseId, Guid seasonId, CancellationToken ct);
    string Fingerprint(JsonElement context);
}
