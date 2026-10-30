using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Infrastructure.Storage;

// Access checks stay in MediaService/EvidenceService. Writes join the caller's
// transaction without flushing unrelated tracked changes.
public sealed class DatabaseMediaStorage(AppDbContext db, FileMediaStorage legacy) : IMediaStorage
{
    private static void Validate(string key)
    {
        if (!Guid.TryParseExact(key, "N", out _)) throw new ArgumentException("Invalid storage key.");
    }
    public async Task WriteAsync(string key, byte[] data, CancellationToken ct)
    {
        Validate(key);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"INSERT INTO \"PrivateMediaFiles\" (\"StorageKey\", \"Data\") VALUES ({key}, {data})", ct);
    }
    public async Task<Stream> ReadAsync(string key, CancellationToken ct)
    {
        Validate(key);
        var data = await db.PrivateMediaFiles.AsNoTracking().Where(x => x.StorageKey == key)
            .Select(x => x.Data).SingleOrDefaultAsync(ct);
        return data == null ? await legacy.ReadAsync(key, ct) : new MemoryStream(data, writable: false);
    }
    public async Task DeleteAsync(string key, CancellationToken ct)
    {
        Validate(key);
        await db.PrivateMediaFiles.Where(x => x.StorageKey == key).ExecuteDeleteAsync(ct);
        await legacy.DeleteAsync(key, ct);
    }
}
