using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Hosting;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using SkiaSharp;

namespace ChoreWars.Infrastructure.Storage;

public sealed class AvatarStorage(IHostEnvironment environment, AppDbContext db, IHttpClientFactory clients) : IAvatarStorage
{
    private const int MaxAvatarBytes = 5 * 1024 * 1024;
    private string Root => Path.Combine(environment.ContentRootPath, ".local-data", "avatars");
    private static string? ContentType(string extension) => extension switch {
        ".png" => "image/png", ".jpg" or ".jpeg" => "image/jpeg", ".webp" => "image/webp", _ => null
    };
    public async Task<string> WriteAsync(byte[] bytes, string extension, CancellationToken ct)
    {
        if (ContentType(extension) == null || bytes.Length is <1 or >MaxAvatarBytes) throw new DomainException("Choose a JPG, PNG or WebP avatar up to 5 MB.");
        using var data = SKData.CreateCopy(bytes);
        using var codec = SKCodec.Create(data);
        if (codec == null || codec.Info.Width <= 0 || codec.Info.Height <= 0 ||
            codec.Info.Width > 4096 || codec.Info.Height > 4096 ||
            (codec.EncodedFormat switch { SKEncodedImageFormat.Png => extension != ".png", SKEncodedImageFormat.Jpeg => extension is not (".jpg" or ".jpeg"), SKEncodedImageFormat.Webp => extension != ".webp", _ => true }))
            throw new DomainException("Choose a valid JPG, PNG or WebP image up to 4096 pixels per side.");
        var id = Guid.NewGuid();
        db.AvatarImages.Add(new AvatarImage { Id = id, Data = bytes, ContentType = ContentType(extension)!, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync(ct);
        return $"/avatars/{id}{extension}";
    }
    public async Task<(Stream Stream, string ContentType)> ReadAsync(string avatarUrl, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (Uri.TryCreate(avatarUrl, UriKind.Absolute, out var remote) && remote.Scheme == Uri.UriSchemeHttps)
            return await ReadGoogleAsync(remote, ct);
        var name = Path.GetFileName(avatarUrl);
        if (avatarUrl != $"/avatars/{name}" || !Guid.TryParse(Path.GetFileNameWithoutExtension(name), out var id)) throw new NotFoundException("Avatar unavailable.");
        var contentType = ContentType(Path.GetExtension(name).ToLowerInvariant()) ?? throw new NotFoundException("Avatar unavailable.");
        var saved = await db.AvatarImages.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        if (saved != null) return (new MemoryStream(saved.Data, false), saved.ContentType);
        try {
            var path = Path.Combine(Root, name);
            if (!File.Exists(path)) path = Path.Combine(environment.ContentRootPath, "wwwroot", "avatars", name);
            Stream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
            return (stream, contentType);
        } catch (FileNotFoundException) { throw new NotFoundException("Avatar unavailable."); }
        catch (DirectoryNotFoundException) { throw new NotFoundException("Avatar unavailable."); }
    }

    private async Task<(Stream Stream, string ContentType)> ReadGoogleAsync(Uri uri, CancellationToken ct)
    {
        // Only Google's profile photo hosts; never proxy arbitrary URLs or follow redirects.
        if (!uri.IsDefaultPort || !string.IsNullOrEmpty(uri.UserInfo) ||
            !(uri.Host.Equals("googleusercontent.com", StringComparison.OrdinalIgnoreCase) ||
              uri.Host.EndsWith(".googleusercontent.com", StringComparison.OrdinalIgnoreCase)))
            throw new NotFoundException("Avatar unavailable.");
        try
        {
            using var client = clients.CreateClient("google-avatar");
            using var response = await client.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, ct);
            var type = response.Content.Headers.ContentType?.MediaType;
            if (!response.IsSuccessStatusCode || type is not ("image/png" or "image/jpeg" or "image/webp") ||
                response.Content.Headers.ContentLength > MaxAvatarBytes) throw new NotFoundException("Avatar unavailable.");
            await using var input = await response.Content.ReadAsStreamAsync(ct);
            using var output = new MemoryStream();
            var buffer = new byte[81920];
            int size;
            while ((size = await input.ReadAsync(buffer, ct)) > 0)
            {
                if (output.Length + size > MaxAvatarBytes) throw new NotFoundException("Avatar unavailable.");
                await output.WriteAsync(buffer.AsMemory(0, size), ct);
            }
            if (output.Length == 0) throw new NotFoundException("Avatar unavailable.");
            return (new MemoryStream(output.ToArray(), false), type!);
        }
        catch (HttpRequestException) { throw new NotFoundException("Avatar unavailable."); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new NotFoundException("Avatar unavailable."); }
    }
}
