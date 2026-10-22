using System.Text.Json;
using ChoreWars.Application.DTOs.AI;

namespace ChoreWars.Application.Interfaces.Services;

public interface IAIHousekeeperService
{
    Task<JsonElement> ReadAsync(Guid house, Guid actor, string path, bool ownerOnly, CancellationToken ct);
    Task<JsonElement> GenerateAsync(Guid house, Guid actor, AIGenerateRequest request, CancellationToken ct);
    Task<JsonElement> RecommendationAsync(Guid house, Guid actor, Guid id, CancellationToken ct);
    Task<JsonElement> AcceptAsync(Guid house, Guid actor, Guid id, CancellationToken ct);
    Task<JsonElement> RejectAsync(Guid house, Guid actor, Guid id, CancellationToken ct);
    Task<JsonElement> InterpretAsync(Guid house, Guid actor, AITextRequest request, bool chat, CancellationToken ct);
    Task<JsonElement> SettingsAsync(Guid house, Guid actor, bool? enabled, bool? chatAuto, CancellationToken ct);
    Task<JsonElement> ConsentAsync(Guid house, Guid actor, bool? enabled, CancellationToken ct);
    Task<JsonElement> ChatInsightsAsync(Guid house, Guid actor, CancellationToken ct);
    Task<JsonElement> EvaluateAsync(Guid house, Guid actor, Guid season, CancellationToken ct);
    Task<JsonElement> BountySuggestionsAsync(Guid house, Guid actor, CancellationToken ct);
    Task<JsonElement> SetAvailabilityExceptionAsync(Guid house, Guid actor, AIAvailabilityExceptionRequest request, CancellationToken ct);
    Task<JsonElement> OwnRiskAsync(Guid house, Guid actor, CancellationToken ct);
    Task<JsonElement> ConfirmAvailabilityAsync(Guid house, Guid actor, AIAvailabilityChangeRequest request, CancellationToken ct);
    Task<JsonElement> ObserveAsync(Guid house, Guid actor, AIObservationRequest request, CancellationToken ct);
}
