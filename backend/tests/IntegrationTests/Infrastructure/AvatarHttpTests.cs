using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Moq;

namespace IntegrationTests.Infrastructure;

public class AvatarHttpTests
{
    private static readonly byte[] Png = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWZkAAAAASUVORK5CYII=");
    private static async Task<(Guid Id, string Token)> Login(HttpClient client)
    {
        var credentials = new { email = $"{Guid.NewGuid():N}@example.test", password = "TestPassword1!", displayName = "Avatar user" };
        (await client.PostAsJsonAsync("/api/auth/register", credentials)).EnsureSuccessStatusCode();
        var result = await client.PostAsJsonAsync("/api/auth/login", credentials); result.EnsureSuccessStatusCode();
        var session = await result.Content.ReadFromJsonAsync<JsonElement>(); var token = session.GetProperty("token").GetString()!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (session.GetProperty("userId").GetGuid(), token);
    }
    [PostgresFact]
    public async Task UploadSurvivesANewServerWithAnEmptyFilesystemAndMissingImagesReturnNoContent()
    {
        await using var database = await PostgresFixture.CreateAsync();
        using var source = new ApiFactory(database);
        var root = Path.Combine(Directory.GetCurrentDirectory(), "artifacts", "runtime", "avatars-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        await File.WriteAllTextAsync(Path.Combine(root, "appsettings.json"), JsonSerializer.Serialize(new {
            ConnectionStrings = new { DefaultConnection = database.ConnectionString },
            Jwt = new { Secret = "integration-test-signing-secret-at-least-sixty-four-characters-long-2026", Issuer = "ChoreWarsTest", Audience = "ChoreWarsTestUsers" }
        }));
        using var first = source.WithWebHostBuilder(b => b.UseContentRoot(root));
        using var client = first.CreateClient(); var account = await Login(client);
        Assert.Equal(HttpStatusCode.NoContent, (await client.GetAsync("/api/user/avatar-image")).StatusCode);
        using var upload = new MultipartFormDataContent();
        upload.Add(new ByteArrayContent(Png), "file", "profile.png");
        var saved = await client.PostAsync("/api/user/avatar", upload); saved.EnsureSuccessStatusCode();
        var url = (await saved.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("avatarUrl").GetString(); Assert.StartsWith("/avatars/", url);
        var otherRoot = root + "-new-server"; Directory.CreateDirectory(otherRoot);
        File.Copy(Path.Combine(root, "appsettings.json"), Path.Combine(otherRoot, "appsettings.json"));
        using var restarted = source.WithWebHostBuilder(b => b.UseContentRoot(otherRoot));
        using var again = restarted.CreateClient(); again.DefaultRequestHeaders.Authorization = new("Bearer", account.Token);
        var read = await again.GetAsync("/api/user/avatar-image"); read.EnsureSuccessStatusCode();
        Assert.Equal(Png, await read.Content.ReadAsByteArrayAsync());
        Assert.Equal("image/png", read.Content.Headers.ContentType!.MediaType);
        Assert.Contains("no-store", read.Headers.CacheControl!.ToString());
        await using (var scope = restarted.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Single(await db.AvatarImages.ToListAsync());
            (await db.Users.SingleAsync()).AvatarUrl = "/avatars/" + Guid.NewGuid() + ".png"; await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.NoContent, (await again.GetAsync("/api/user/avatar-image")).StatusCode);
        using var anonymous = restarted.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/user/avatar-image")).StatusCode);
        using var invalid = new MultipartFormDataContent(); invalid.Add(new ByteArrayContent([1, 2, 3]), "file", "fake.png");
        Assert.Equal(HttpStatusCode.BadRequest, (await again.PostAsync("/api/user/avatar", invalid)).StatusCode);
    }

    private sealed class GoogleHandler : HttpMessageHandler
    {
        public int Calls;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++; Assert.Equal("lh3.googleusercontent.com", request.RequestUri!.Host);
            Assert.Null(request.Headers.Authorization);
            var response = new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(Png) };
            response.Content.Headers.ContentType = new("image/png"); return Task.FromResult(response);
        }
    }
    [PostgresFact]
    public async Task GooglePhotoUsesAnUnauthenticatedRestrictedProxyAndRejectsOtherHosts()
    {
        await using var database = await PostgresFixture.CreateAsync(); using var source = new ApiFactory(database);
        var handler = new GoogleHandler(); var clients = new Mock<IHttpClientFactory>();
        clients.Setup(c => c.CreateClient("google-avatar")).Returns(() => new HttpClient(handler, false));
        using var factory = source.WithWebHostBuilder(b => b.ConfigureTestServices(s => { s.RemoveAll<IHttpClientFactory>(); s.AddSingleton(clients.Object); }));
        using var client = factory.CreateClient(); await Login(client);
        async Task Photo(string url) { await using var scope = factory.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDbContext>(); (await db.Users.SingleAsync()).AvatarUrl = url; await db.SaveChangesAsync(); }
        await Photo("https://lh3.googleusercontent.com/a/test-profile");
        Assert.Equal(Png, await client.GetByteArrayAsync("/api/user/avatar-image")); Assert.Equal(1, handler.Calls);
        foreach (var url in new[] { "https://googleusercontent.com.evil.example/p", "https://127.0.0.1/p", "https://lh3.googleusercontent.com:8080/p" })
        {
            await Photo(url); Assert.Equal(HttpStatusCode.NoContent, (await client.GetAsync("/api/user/avatar-image")).StatusCode);
        }
        Assert.Equal(1, handler.Calls);
    }
}
