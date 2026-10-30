namespace ChoreWars.Domain.Entities;
public sealed class PrivateMediaFile
{
    public string StorageKey { get; set; } = "";
    public byte[] Data { get; set; } = [];
}
