using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Storage;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public sealed class DurableMediaTests
{
    [PostgresFact]
    public async Task MediaPersistsWithoutFilesAndParticipatesInTransactionRollback()
    {
        await using var database = await PostgresFixture.CreateAsync();
        await using var scope = database.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var directory = Path.Combine(Path.GetTempPath(), "cw-media-test-" + Guid.NewGuid().ToString("N"));
        var legacy = new FileMediaStorage(Options.Create(new MediaStorageOptions { RootPath = directory }));
        var storage = new DatabaseMediaStorage(db, legacy);
        var key = Guid.NewGuid().ToString("N");
        byte[] bytes = [1, 2, 3, 4, 5];
        await storage.WriteAsync(key, bytes, default);
        Assert.False(Directory.Exists(directory));
        await using var otherScope = database.Services.CreateAsyncScope();
        var fresh = otherScope.ServiceProvider.GetRequiredService<AppDbContext>();
        IMediaStorage restarted = new DatabaseMediaStorage(fresh, legacy);
        await using (var stream = await restarted.ReadAsync(key, default))
        { using var buffer = new MemoryStream(); await stream.CopyToAsync(buffer); Assert.Equal(bytes, buffer.ToArray()); }
        var rolledBack = Guid.NewGuid().ToString("N");
        await using (var transaction = await db.Database.BeginTransactionAsync())
        { await storage.WriteAsync(rolledBack, bytes, default); await transaction.RollbackAsync(); }
        await Assert.ThrowsAsync<NotFoundException>(() => restarted.ReadAsync(rolledBack, default));
        await storage.DeleteAsync(key, default);
        await Assert.ThrowsAsync<NotFoundException>(() => restarted.ReadAsync(key, default));
        await Assert.ThrowsAsync<ArgumentException>(() => storage.WriteAsync("../bad", bytes, default));
    }
}
