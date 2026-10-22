using System.Text.Json;

namespace ChoreWars.Application.Interfaces.Services;

public interface IAIHousekeeperClient
{
    Task<JsonElement> GetAsync(Guid houseId, Guid actorId, string path, CancellationToken ct);
    Task<JsonElement> PostAsync(Guid houseId, Guid actorId, string path, object payload, CancellationToken ct);
}
