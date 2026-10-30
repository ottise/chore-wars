using System.Collections.Concurrent;
using System.Net;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public sealed class CloudinaryStorageTests
{
    // Simulates Cloudinary's API, not its database locator or backend storage routing.
    private sealed class Cloud : HttpMessageHandler
    {
        public readonly ConcurrentDictionary<string, byte[]> Files = new();
        public bool FailUploads;
        public int Downloads;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            if (request.RequestUri!.AbsolutePath.EndsWith("/upload"))
            {
                if (FailUploads) return new(HttpStatusCode.ServiceUnavailable);
                var fields = ((MultipartFormDataContent)request.Content!).ToDictionary(x => x.Headers.ContentDisposition!.Name!.Trim('"'));
                var id = await fields["public_id"].ReadAsStringAsync(ct);
                Files[id] = await fields["file"].ReadAsByteArrayAsync(ct);
                return new(HttpStatusCode.OK) { Content = new StringContent(JsonSerializer.Serialize(new { asset_id = id, public_id = id, type = "authenticated", resource_type = "raw" })) };
            }
            var values = (await request.Content!.ReadAsStringAsync(ct)).Split('&').Select(x => x.Split('=', 2))
                .ToDictionary(x => x[0], x => Uri.UnescapeDataString(x[1]));
            if (request.RequestUri.AbsolutePath.EndsWith("/download"))
            {
                Downloads++;
                return Files.TryGetValue(values["asset_id"], out var bytes)
                    ? new(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) } : new(HttpStatusCode.NotFound);
            }
            Files.TryRemove(values["public_id"], out _);
            return new(HttpStatusCode.OK) { Content = new StringContent("{\"result\":\"ok\"}") };
        }
    }

    [PostgresFact]
    public async Task NewMediaAndAvatarUseCloudAndOldDatabaseFilesSurviveNewScopes()
    {
        using var cloud = new Cloud();
        await using var fixture = await PostgresFixture.CreateAsync(configure: services => {
            services.AddTransient(_ => new CloudinaryClient(new HttpClient(cloud, false), CloudinaryOptions.Parse("cloudinary://123:test-secret@unit-cloud")));
            var environment = new Moq.Mock<Microsoft.Extensions.Hosting.IHostEnvironment>();
            environment.SetupGet(x => x.ContentRootPath).Returns(Path.GetTempPath());
            services.AddSingleton(environment.Object);
        });
        var key = Guid.NewGuid().ToString("N"); var oldKey = Guid.NewGuid().ToString("N");
        var png = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWZkAAAAASUVORK5CYII=");
        string avatar;
        await using (var scope = fixture.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.PrivateMediaFiles.Add(new PrivateMediaFile { StorageKey = oldKey, Data = [9, 8] });
            await db.SaveChangesAsync();
            await scope.ServiceProvider.GetRequiredService<IMediaStorage>().WriteAsync(key, [82, 73, 70, 70], default);
            avatar = await scope.ServiceProvider.GetRequiredService<IAvatarStorage>().WriteAsync(png, ".png", default);
            Assert.Equal(2, await db.CloudinaryFiles.CountAsync());
            Assert.Single(await db.PrivateMediaFiles.ToListAsync());
            Assert.Empty(await db.AvatarImages.ToListAsync());
        }
        // New DI scope has no original tracked entity, local bytes or in-memory URL.
        await using (var scope = fixture.Services.CreateAsyncScope())
        {
            var storage = scope.ServiceProvider.GetRequiredService<IMediaStorage>();
            await using var stream = await storage.ReadAsync(key, default);
            using var output = new MemoryStream(); await stream.CopyToAsync(output);
            Assert.Equal(new byte[] { 82, 73, 70, 70 }, output.ToArray());
            await using var old = await storage.ReadAsync(oldKey, default);
            Assert.Equal(9, old.ReadByte()); Assert.Equal(8, old.ReadByte());
            var image = await scope.ServiceProvider.GetRequiredService<IAvatarStorage>().ReadAsync(avatar, default);
            await using var imageStream = image.Stream;
            using var imageBytes = new MemoryStream(); await imageStream.CopyToAsync(imageBytes);
            Assert.Equal(png, imageBytes.ToArray()); Assert.Equal("image/png", image.ContentType);
            Assert.Equal(2, cloud.Downloads); // Reading DB media never contacts Cloudinary.
            await Assert.ThrowsAsync<ChoreWars.Domain.Exceptions.ConflictException>(() => storage.WriteAsync(key, [0], default));
            Assert.Equal(new byte[] { 82, 73, 70, 70 }, cloud.Files["chore-wars/media-" + key]);
            await storage.DeleteAsync(key, default); await storage.DeleteAsync(key, default);
            Assert.Single(await scope.ServiceProvider.GetRequiredService<AppDbContext>().CloudinaryFiles.ToListAsync());
        }
    }

    [PostgresFact]
    public async Task UploadFailureDoesNotSilentlyFallBackOrCreateABrokenLocator()
    {
        using var cloud = new Cloud { FailUploads = true };
        await using var fixture = await PostgresFixture.CreateAsync(configure: services =>
            services.AddTransient(_ => new CloudinaryClient(new HttpClient(cloud, false), CloudinaryOptions.Parse("cloudinary://123:test-secret@unit-cloud"))));
        await using var scope = fixture.Services.CreateAsyncScope();
        await Assert.ThrowsAsync<ChoreWars.Domain.Exceptions.DomainException>(() => scope.ServiceProvider.GetRequiredService<IMediaStorage>()
            .WriteAsync(Guid.NewGuid().ToString("N"), [1, 2, 3], default));
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Empty(await db.CloudinaryFiles.ToListAsync()); Assert.Empty(await db.PrivateMediaFiles.ToListAsync());
    }
}
