namespace ChoreWars.Application.Interfaces.Services;

public interface IAvatarStorage
{
    Task<string> WriteAsync(byte[] bytes, string extension, CancellationToken ct);
    Task<(Stream Stream, string ContentType)> ReadAsync(string avatarUrl, CancellationToken ct);
}
