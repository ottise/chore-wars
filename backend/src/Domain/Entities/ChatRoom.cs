using System;
using System.Collections.Generic;

namespace ChoreWars.Domain.Entities;

public class ChatRoom
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }

    public House House { get; set; } = null!;
    public ICollection<ChatMessage> Messages { get; set; } = new List<ChatMessage>();
}
