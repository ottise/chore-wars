using System;

namespace ChoreWars.Application.DTOs.Chat;

public class ChatRoomResponse
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public string Name { get; set; } = string.Empty;
}
