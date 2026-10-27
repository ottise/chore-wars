using System.Text.Json;
using ChoreWars.Application.DTOs.AI;

namespace ChoreWars.Application.Interfaces.Services;

public interface IEvidenceService
{
    Task<JsonElement> UploadAsync(Guid occurrenceId, Guid actor, Guid requestId, byte[] bytes, CancellationToken ct);
    Task<AIEvidenceContent> ReadAsync(Guid evidenceId, Guid actor, CancellationToken ct);
    Task<JsonElement> VerifyAsync(Guid occurrenceId, Guid evidenceId, Guid actor, CancellationToken ct);
    Task AttachAsync(Guid occurrenceId, Guid evidenceId, Guid actor, CancellationToken ct);
    Task SaveAsync(Guid occurrenceId, Guid evidenceId, Guid actor, CancellationToken ct);
}
