using System;

namespace ChoreWars.Domain.Entities;

public class ChatMessage
{
    public string MessageType { get; set; } = "TEXT";
    public Guid? AttachmentId { get; set; }
    public Guid? ClientMessageId { get; set; }
    public Guid Id { get; set; }
    public Guid RoomId { get; set; }
    public Guid SenderId { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? EditedAt { get; set; }

    public ChatRoom Room { get; set; } = null!;
    public User Sender { get; set; } = null!;
}
