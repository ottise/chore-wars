using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Infrastructure.Storage;

public sealed class CloudinaryFileStore(AppDbContext db, CloudinaryClient client, ILogger<CloudinaryFileStore> logger)
{
    public bool Enabled => client.Enabled;

    public async Task WriteAsync(string key, byte[] data, CancellationToken ct)
    {
        if (await db.CloudinaryFiles.AnyAsync(x => x.StorageKey == key, ct))
            throw new ChoreWars.Domain.Exceptions.ConflictException("This media file already exists.");
        var file = await client.UploadAsync(key, data, ct);
        try
        {
            // Joins the caller's existing transaction; does not flush other tracked entities.
            await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"CloudinaryFiles\" (\"StorageKey\", \"CloudName\", \"AssetId\", \"PublicId\", \"ResourceType\") VALUES ({key}, {file.CloudName}, {file.AssetId}, {file.PublicId}, {file.ResourceType})", ct);
        }
        catch
        {
            try { await client.DeleteAsync(file, CancellationToken.None); }
            catch { logger.LogWarning("Cloudinary upload cleanup failed; an unreferenced asset may need removal."); }
            throw;
        }
    }

    public async Task<Stream?> TryReadAsync(string key, CancellationToken ct)
    {
        var file = await db.CloudinaryFiles.AsNoTracking().SingleOrDefaultAsync(x => x.StorageKey == key, ct);
        return file == null ? null : await client.ReadAsync(file, ct);
    }

    public async Task DeleteAsync(string key, CancellationToken ct)
    {
        var file = await db.CloudinaryFiles.AsNoTracking().SingleOrDefaultAsync(x => x.StorageKey == key, ct);
        if (file == null) return;
        await client.DeleteAsync(file, ct);
        await db.CloudinaryFiles.Where(x => x.StorageKey == key).ExecuteDeleteAsync(ct);
    }
}
