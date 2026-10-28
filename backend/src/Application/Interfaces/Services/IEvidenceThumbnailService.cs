namespace ChoreWars.Application.Interfaces.Services;
public interface IEvidenceThumbnailService
{
    Task<byte[]> ReadAsync(Guid evidenceId, Guid actor, CancellationToken ct);
}
