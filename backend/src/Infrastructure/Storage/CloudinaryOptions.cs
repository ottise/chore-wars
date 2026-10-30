using System.Text.RegularExpressions;

namespace ChoreWars.Infrastructure.Storage;

public sealed class CloudinaryOptions
{
    public string CloudName { get; private init; } = "";
    public string ApiKey { get; private init; } = "";
    public string ApiSecret { get; private init; } = "";
    public bool Enabled => CloudName.Length > 0;

    public static CloudinaryOptions Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return new();
        // Reject extra hosts, paths or options rather than ever sending credentials to a supplied URL.
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != "cloudinary" ||
            !uri.IsDefaultPort || !Regex.IsMatch(uri.Host, "^[a-z0-9_-]+$") ||
            uri.AbsolutePath is not ("" or "/") || uri.Query.Length != 0 || uri.Fragment.Length != 0)
            throw new InvalidOperationException("CLOUDINARY_URL must use cloudinary://API_KEY:API_SECRET@CLOUD_NAME.");
        var parts = uri.UserInfo.Split(':', 2);
        if (parts.Length != 2 || parts.Any(string.IsNullOrWhiteSpace))
            throw new InvalidOperationException("CLOUDINARY_URL requires an API key and API secret.");
        return new() { CloudName = uri.Host, ApiKey = Uri.UnescapeDataString(parts[0]), ApiSecret = Uri.UnescapeDataString(parts[1]) };
    }
}
