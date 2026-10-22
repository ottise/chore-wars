using ChoreWars.Application.DTOs.AI;
using System.Text.Json;

namespace ChoreWars.Application.Interfaces.Services;

public interface IScheduleChangeService
{
    Task<IReadOnlySet<Guid>> ValidateAsync(Guid houseId, ScheduleChangePayload payload, CancellationToken ct);
    Task ApplyAsync(Guid houseId, ScheduleChangePayload payload, CancellationToken ct);
    Task<JsonElement> CandidateContextAsync(Guid houseId, Guid seasonId, JsonElement original, List<ScheduleAvailabilityChange> changes, CancellationToken ct);
}
