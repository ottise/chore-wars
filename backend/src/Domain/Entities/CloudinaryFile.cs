namespace ChoreWars.Domain.Entities;

// Backend-only locator. Never returned in a media or avatar response.
public sealed class CloudinaryFile
{
    public string StorageKey { get; set; } = "";
    public string CloudName { get; set; } = "";
    public string AssetId { get; set; } = "";
    public string PublicId { get; set; } = "";
    public string ResourceType { get; set; } = "";
}
