using System;

namespace ChoreWars.Domain.Entities;

public class ChatMessage
{
    public Guid Id { get; set; }
    public Guid RoomId { get; set; }
    public Guid SenderId { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? EditedAt { get; set; }

    public ChatRoom Room { get; set; } = null!;
    public User Sender { get; set; } = null!;
}
