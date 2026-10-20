namespace ChoreWars.Application.Interfaces.Services;
public interface IMediaStorage {
    Task WriteAsync(string key, byte[] data, CancellationToken ct);
    Task<Stream> ReadAsync(string key, CancellationToken ct);
    Task DeleteAsync(string key, CancellationToken ct);
}
