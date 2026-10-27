using ChoreWars.Application.DTOs.Chat;
namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyChatPublisher { Task PublishAsync(ChatMessageResponse message,CancellationToken ct); }
