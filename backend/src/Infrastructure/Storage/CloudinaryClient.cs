using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Infrastructure.Storage;

public sealed class CloudinaryClient(HttpClient http, CloudinaryOptions options)
{
    public bool Enabled => options.Enabled;
    private const int MaxDownloadBytes = 32 * 1024 * 1024;
    private static DomainException Unavailable() => new("Media storage is temporarily unavailable. Please try again later.");

    private Dictionary<string, string> Sign(Dictionary<string, string> parameters)
    {
        parameters["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture);
        var text = string.Join('&', parameters.OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => $"{x.Key}={x.Value}"));
        parameters["signature"] = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text + options.ApiSecret)));
        parameters["api_key"] = options.ApiKey;
        return parameters;
    }

    private string Endpoint(string action) => $"https://api.cloudinary.com/v1_1/{options.CloudName}/{action}";

    public async Task<CloudinaryFile> UploadAsync(string key, byte[] data, CancellationToken ct)
    {
        if (!Enabled) throw Unavailable();
        // The public ID is opaque; no user/house names or original filenames are sent.
        var publicId = $"chore-wars/{key}";
        using var form = new MultipartFormDataContent();
        foreach (var pair in Sign(new() { ["public_id"] = publicId, ["type"] = "authenticated", ["overwrite"] = "false" }))
            form.Add(new StringContent(pair.Value), pair.Key);
        form.Add(new ByteArrayContent(data), "file", "media");
        try
        {
            using var response = await http.PostAsync(Endpoint("auto/upload"), form, ct);
            if (!response.IsSuccessStatusCode) throw Unavailable();
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            var root = json.RootElement;
            // overwrite=false can return the existing asset. Never let failure compensation delete it.
            if (root.TryGetProperty("existing", out var existing) && existing.ValueKind == JsonValueKind.True)
                throw new ConflictException("This media file already exists.");
            var type = root.GetProperty("resource_type").GetString()!;
            if (root.GetProperty("public_id").GetString() != publicId || root.GetProperty("type").GetString() != "authenticated" ||
                type is not ("image" or "video" or "raw")) throw Unavailable();
            var asset = root.GetProperty("asset_id").GetString();
            if (string.IsNullOrWhiteSpace(asset) || asset.Length > 128) throw Unavailable();
            return new() { StorageKey = key, CloudName = options.CloudName, AssetId = asset, PublicId = publicId, ResourceType = type };
        }
        catch (HttpRequestException) { throw Unavailable(); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw Unavailable(); }
        catch (JsonException) { throw Unavailable(); }
        catch (KeyNotFoundException) { throw Unavailable(); }
    }

    private void EnsureAccount(CloudinaryFile file)
    {
        if (!Enabled || file.CloudName != options.CloudName) throw Unavailable();
    }

    public async Task<Stream> ReadAsync(CloudinaryFile file, CancellationToken ct)
    {
        EnsureAccount(file);
        // POST keeps signed credentials out of URL/access logs. Never forward signed URLs to the frontend.
        using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint("asset/download")) {
            Content = new FormUrlEncodedContent(Sign(new() {
                ["asset_id"] = file.AssetId,
                ["expires_at"] = DateTimeOffset.UtcNow.AddMinutes(1).ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)
            }))
        };
        try
        {
            using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
            if (response.StatusCode == HttpStatusCode.NotFound) throw new NotFoundException("Media file is unavailable.");
            if (!response.IsSuccessStatusCode || response.Content.Headers.ContentLength > MaxDownloadBytes) throw Unavailable();
            await using var input = await response.Content.ReadAsStreamAsync(ct);
            using var output = new MemoryStream();
            var buffer = new byte[81920];
            int count;
            while ((count = await input.ReadAsync(buffer, ct)) > 0)
            {
                if (output.Length + count > MaxDownloadBytes) throw Unavailable();
                await output.WriteAsync(buffer.AsMemory(0, count), ct);
            }
            return new MemoryStream(output.ToArray(), false);
        }
        catch (HttpRequestException) { throw Unavailable(); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw Unavailable(); }
    }

    public async Task DeleteAsync(CloudinaryFile file, CancellationToken ct)
    {
        EnsureAccount(file);
        using var body = new FormUrlEncodedContent(Sign(new() { ["public_id"] = file.PublicId, ["type"] = "authenticated", ["invalidate"] = "true" }));
        try
        {
            using var response = await http.PostAsync(Endpoint($"{file.ResourceType}/destroy"), body, ct);
            if (!response.IsSuccessStatusCode) throw Unavailable();
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            if (json.RootElement.GetProperty("result").GetString() is not ("ok" or "not found")) throw Unavailable();
        }
        catch (HttpRequestException) { throw Unavailable(); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw Unavailable(); }
        catch (JsonException) { throw Unavailable(); }
        catch (KeyNotFoundException) { throw Unavailable(); }
    }
}
