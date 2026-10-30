namespace ChoreWars.Domain.Entities;

public sealed class AvatarImage
{
    public Guid Id { get; set; }
    public byte[] Data { get; set; } = [];
    public string ContentType { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
