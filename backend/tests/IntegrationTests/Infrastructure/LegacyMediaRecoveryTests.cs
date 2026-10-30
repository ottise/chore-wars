using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Storage;
using ChoreWars.Infrastructure.Workers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace IntegrationTests.Infrastructure;

public sealed class LegacyMediaRecoveryTests {
    [PostgresFact]
    public async Task ConcurrentLegacyReadsPromoteBytesAndSurviveLossOfOldDirectory() {
        await using var fixture = await PostgresFixture.CreateAsync();
        var root = Path.Combine(Path.GetTempPath(), "cw-legacy-" + Guid.NewGuid().ToString("N"));
        var legacy = new FileMediaStorage(Options.Create(new MediaStorageOptions { RootPath = root }));
        var key = Guid.NewGuid().ToString("N");
        byte[] bytes = [137,80,78,71,13,10,26,10,1,2,3,4];
        try {
            await legacy.WriteAsync(key, bytes, default);
            async Task<byte[]> Read() {
                await using var scope = fixture.Services.CreateAsyncScope();
                var storage = new DatabaseMediaStorage(scope.ServiceProvider.GetRequiredService<AppDbContext>(), legacy);
                await using var stream = await storage.ReadAsync(key, default);
                using var buffer = new MemoryStream(); await stream.CopyToAsync(buffer); return buffer.ToArray();
            }
            var readers = await Task.WhenAll(Read(), Read());
            Assert.All(readers, result => Assert.Equal(bytes, result));
            await legacy.DeleteAsync(key, default);
            Assert.Equal(bytes, await Read());
            await using var verify = fixture.Services.CreateAsyncScope();
            Assert.Equal(1, await verify.ServiceProvider.GetRequiredService<AppDbContext>().PrivateMediaFiles.CountAsync(f => f.StorageKey == key));
        } finally {
            await legacy.DeleteAsync(key, default);
            if (Directory.Exists(root)) Directory.Delete(root);
        }
    }

    [PostgresFact]
    public async Task OldReferencedImageWithoutAttachedFlagIsPreservedRecoveredAndReadableByOtherMember() {
        var root = Path.Combine(Path.GetTempPath(), "cw-legacy-chat-" + Guid.NewGuid().ToString("N"));
        await using var fixture = await PostgresFixture.CreateAsync(configure: services =>
            services.PostConfigure<MediaStorageOptions>(options => options.RootPath = root));
        var seed = await CoreConcurrencyTests.Seed(fixture);
        var room = Guid.NewGuid(); var sent = Guid.NewGuid(); var missing = Guid.NewGuid(); var orphan = Guid.NewGuid(); var unsent = Guid.NewGuid();
        var legacy = new FileMediaStorage(Options.Create(new MediaStorageOptions { RootPath = root }));
        byte[] bytes = [137,80,78,71,13,10,26,10,1,2,3,4];
        try {
            await using (var setup = fixture.Services.CreateAsyncScope()) {
                var db = setup.ServiceProvider.GetRequiredService<AppDbContext>();
                db.ChatRooms.Add(new ChatRoom { Id = room, HouseId = seed.HouseId, Name = "Household Chat", CreatedAt = DateTime.UtcNow.AddDays(-3) });
                foreach (var id in new[] { sent, missing, orphan, unsent })
                    db.MediaAttachments.Add(new MediaAttachment { Id = id, RoomId = room, OwnerId = seed.Users[0], Type = "IMAGE", ContentType = "image/png",
                        Size = bytes.Length, StorageKey = id.ToString("N"), CreatedAt = id == unsent ? DateTime.UtcNow : DateTime.UtcNow.AddDays(-2) });
                foreach (var id in new[] { sent, missing })
                    db.ChatMessages.Add(new ChatMessage { Id = Guid.NewGuid(), RoomId = room, SenderId = seed.Users[0], MessageType = "IMAGE", AttachmentId = id, CreatedAt = DateTime.UtcNow.AddDays(-2) });
                await db.SaveChangesAsync();
            }
            await legacy.WriteAsync(sent.ToString("N"), bytes, default);
            await legacy.WriteAsync(orphan.ToString("N"), bytes, default);
            var scopes = fixture.Services.GetRequiredService<IServiceScopeFactory>();
            await new MediaCleanupWorker(scopes, NullLogger<MediaCleanupWorker>.Instance).CleanupAsync(default);
            Assert.True(File.Exists(Path.Combine(root, sent.ToString("N"))));
            Assert.False(File.Exists(Path.Combine(root, orphan.ToString("N"))));
            var result = await new LegacyMediaMigrationWorker(scopes, NullLogger<LegacyMediaMigrationWorker>.Instance).MigrateAsync(default);
            Assert.Equal((1, 1), result);
            await legacy.DeleteAsync(sent.ToString("N"), default); // Simulate old filesystem disappearing on deploy.
            await using var reload = fixture.Services.CreateAsyncScope();
            var service = reload.ServiceProvider.GetRequiredService<IMediaService>();
            var download = await service.DownloadAsync(sent, seed.Users[1], default);
            await using (var stream = download.Stream) {
                using var buffer = new MemoryStream(); await stream.CopyToAsync(buffer); Assert.Equal(bytes, buffer.ToArray());
            }
            await Assert.ThrowsAsync<ForbiddenException>(() => service.DownloadAsync(unsent, seed.Users[1], default));
            await Assert.ThrowsAsync<NotFoundException>(() => service.DownloadAsync(missing, seed.Users[1], default));
            var verify = reload.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(2, await verify.ChatMessages.CountAsync()); // Missing files do not erase history.
            Assert.False(await verify.MediaAttachments.AnyAsync(m => m.Id == orphan));
        } finally {
            await legacy.DeleteAsync(sent.ToString("N"), default);
            await legacy.DeleteAsync(orphan.ToString("N"), default);
            if (Directory.Exists(root)) Directory.Delete(root);
        }
    }
}
