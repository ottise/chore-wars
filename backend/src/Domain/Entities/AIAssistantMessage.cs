using System;

namespace ChoreWars.Domain.Entities;

public sealed class AIAssistantMessage
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid UserId { get; set; }
    public string Role { get; set; } = "USER";
    public string Content { get; set; } = string.Empty;
    public string? PayloadJson { get; set; }
    public DateTime CreatedAt { get; set; }
}
