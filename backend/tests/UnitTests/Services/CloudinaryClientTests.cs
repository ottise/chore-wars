using System.Net;
using System.Security.Cryptography;
using System.Text;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Storage;

namespace UnitTests.Services;

public sealed class CloudinaryClientTests
{
    private const string Secret = "unit-test-secret";
    private static CloudinaryOptions Options => CloudinaryOptions.Parse($"cloudinary://123:{Secret}@unit-cloud");
    private sealed class Handler(Func<HttpRequestMessage, Task<HttpResponseMessage>> run) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => run(request);
    }
    private static CloudinaryClient Client(Func<HttpRequestMessage, Task<HttpResponseMessage>> run) => new(new HttpClient(new Handler(run)), Options);
    private static CloudinaryFile File => new() { CloudName = "unit-cloud", AssetId = "asset", PublicId = "chore-wars/media-key", ResourceType = "video" };
    private static Dictionary<string, string> Decode(string body) => body.Split('&').Select(x => x.Split('=', 2))
        .ToDictionary(x => Uri.UnescapeDataString(x[0]), x => Uri.UnescapeDataString(x[1].Replace('+', ' ')));
    private static void AssertSignature(Dictionary<string, string> parameters)
    {
        var signature = parameters["signature"];
        var text = string.Join('&', parameters.Where(x => x.Key is not ("signature" or "api_key"))
            .OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => $"{x.Key}={x.Value}"));
        Assert.Equal(Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text + Secret))), signature);
    }

    [Fact]
    public void MissingConfigurationKeepsDatabaseStorageAndEncodedCredentialsAreDecoded()
    {
        Assert.False(CloudinaryOptions.Parse(null).Enabled);
        var value = CloudinaryOptions.Parse("cloudinary://123:secret%3Avalue@unit-cloud");
        Assert.True(value.Enabled); Assert.Equal("secret:value", value.ApiSecret);
    }

    [Theory]
    [InlineData("https://123:secret@unit-cloud")]
    [InlineData("cloudinary://123@unit-cloud")]
    [InlineData("cloudinary://123:secret@unit-cloud/path")]
    [InlineData("cloudinary://123:secret@unit-cloud?x=y")]
    public void InvalidConfigurationDoesNotExposeTheValue(string value)
    {
        var error = Assert.Throws<InvalidOperationException>(() => CloudinaryOptions.Parse(value));
        Assert.DoesNotContain(value, error.Message);
    }

    [Theory]
    [InlineData("image")]
    [InlineData("video")]
    [InlineData("raw")]
    public async Task UploadAlwaysUsesAuthenticatedAssetsAndSignedOpaqueIds(string type)
    {
        var client = Client(async request => {
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal("https://api.cloudinary.com/v1_1/unit-cloud/auto/upload", request.RequestUri!.AbsoluteUri);
            Assert.Null(request.Headers.Authorization);
            var fields = new Dictionary<string, string>();
            foreach (var part in Assert.IsType<MultipartFormDataContent>(request.Content))
                fields[part.Headers.ContentDisposition!.Name!.Trim('"')] = await part.ReadAsStringAsync();
            Assert.Equal("authenticated", fields["type"]); Assert.Equal("false", fields["overwrite"]);
            Assert.Equal("chore-wars/media-key", fields["public_id"]);
            fields.Remove("file"); AssertSignature(fields);
            return new(HttpStatusCode.OK) { Content = new StringContent($$"""{"asset_id":"asset","public_id":"chore-wars/media-key","type":"authenticated","resource_type":"{{type}}"}""") };
        });
        var file = await client.UploadAsync("media-key", [1, 2, 3], default);
        Assert.Equal(type, file.ResourceType); Assert.Equal("asset", file.AssetId);
    }

    [Fact]
    public async Task ExistingUploadIsRejectedBeforeItCanBeDeletedByCompensation()
    {
        var client = Client(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) {
            Content = new StringContent("{\"existing\":true}")
        }));
        await Assert.ThrowsAsync<ConflictException>(() => client.UploadAsync("media-key", [1, 2, 3], default));
    }

    [Fact]
    public async Task DownloadUsesExpiringServerSidePostAndPreservesBytes()
    {
        var client = Client(async request => {
            Assert.Equal(HttpMethod.Post, request.Method); Assert.EndsWith("/asset/download", request.RequestUri!.AbsoluteUri);
            Assert.Equal("", request.RequestUri.Query);
            var fields = Decode(await request.Content!.ReadAsStringAsync());
            AssertSignature(fields); Assert.Equal("asset", fields["asset_id"]);
            Assert.InRange(long.Parse(fields["expires_at"]), DateTimeOffset.UtcNow.ToUnixTimeSeconds(), DateTimeOffset.UtcNow.AddMinutes(2).ToUnixTimeSeconds());
            return new(HttpStatusCode.OK) { Content = new ByteArrayContent([1, 2, 3]) };
        });
        await using var stream = await client.ReadAsync(File, default);
        using var output = new MemoryStream(); await stream.CopyToAsync(output);
        Assert.Equal(new byte[] { 1, 2, 3 }, output.ToArray());
    }

    [Fact]
    public async Task DeleteUsesOriginalResourceTypeAndAuthenticatedDeliveryType()
    {
        var client = Client(async request => {
            Assert.EndsWith("/video/destroy", request.RequestUri!.AbsoluteUri);
            var fields = Decode(await request.Content!.ReadAsStringAsync());
            AssertSignature(fields); Assert.Equal("authenticated", fields["type"]); Assert.Equal("true", fields["invalidate"]);
            return new(HttpStatusCode.OK) { Content = new StringContent("{\"result\":\"not found\"}") };
        });
        await client.DeleteAsync(File, default);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized)]
    [InlineData(HttpStatusCode.TooManyRequests)]
    [InlineData(HttpStatusCode.Redirect)]
    public async Task ProviderFailuresAreBoundedAndNeverDiscloseCredentials(HttpStatusCode status)
    {
        var calls = 0;
        var client = Client(_ => { calls++; return Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(Secret) }); });
        var error = await Assert.ThrowsAsync<DomainException>(() => client.ReadAsync(File, default));
        Assert.DoesNotContain(Secret, error.ToString()); Assert.Equal(1, calls);
    }

    [Fact]
    public async Task RemovedOrDifferentAccountDoesNotFallThroughToAFileOrAnotherCloud()
    {
        var client = Client(_ => throw new Exception("Should never send"));
        var file = File; file.CloudName = "other-cloud";
        await Assert.ThrowsAsync<DomainException>(() => client.ReadAsync(file, default));
    }
}
