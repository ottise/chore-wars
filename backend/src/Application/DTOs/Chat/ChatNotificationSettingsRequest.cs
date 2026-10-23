using System.ComponentModel.DataAnnotations;

namespace ChoreWars.Application.DTOs.Chat;

public sealed class ChatNotificationSettingsRequest
{
    [Required]
    public bool? Enabled { get; set; }
}
