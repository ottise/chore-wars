using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Hosting;

namespace ChoreWars.Infrastructure.Storage;

public sealed class AvatarStorage(IHostEnvironment environment) : IAvatarStorage
{
    private const int MaxAvatarBytes = 5 * 1024 * 1024;
    private string Root => Path.Combine(environment.ContentRootPath, ".local-data", "avatars");
    private static string? ContentType(string extension) => extension switch {
        ".png" => "image/png", ".jpg" or ".jpeg" => "image/jpeg", ".webp" => "image/webp", _ => null
    };
    public async Task<string> WriteAsync(byte[] bytes, string extension, CancellationToken ct)
    {
        if (ContentType(extension) == null || bytes.Length is <1 or >MaxAvatarBytes) throw new DomainException("Choose a JPG, PNG or WebP avatar up to 5 MB.");
        Directory.CreateDirectory(Root);
        var name = Guid.NewGuid() + extension;
        await using var stream = new FileStream(Path.Combine(Root, name), FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true);
        await stream.WriteAsync(bytes, ct);
        return $"/avatars/{name}";
    }
    public Task<(Stream Stream, string ContentType)> ReadAsync(string avatarUrl, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var name = Path.GetFileName(avatarUrl);
        if (avatarUrl != $"/avatars/{name}" || !Guid.TryParse(Path.GetFileNameWithoutExtension(name), out _)) throw new NotFoundException("Avatar unavailable.");
        var contentType = ContentType(Path.GetExtension(name).ToLowerInvariant()) ?? throw new NotFoundException("Avatar unavailable.");
        try {
            var path = Path.Combine(Root, name);
            if (!File.Exists(path)) path = Path.Combine(environment.ContentRootPath, "wwwroot", "avatars", name);
            Stream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
            return Task.FromResult((stream, contentType));
        } catch (FileNotFoundException) { throw new NotFoundException("Avatar unavailable."); }
        catch (DirectoryNotFoundException) { throw new NotFoundException("Avatar unavailable."); }
    }
}
