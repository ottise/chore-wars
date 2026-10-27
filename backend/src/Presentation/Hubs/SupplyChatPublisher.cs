using ChoreWars.Application.DTOs.Chat;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.SignalR;
namespace ChoreWars.Presentation.Hubs;
public sealed class SupplyChatPublisher(IHubContext<ChatHub> hub):ISupplyChatPublisher {
 public Task PublishAsync(ChatMessageResponse message,CancellationToken ct)=>hub.Clients.Group(ChatHub.RoomGroup(message.RoomId)).SendAsync("MessageReceived",message,ct);
}
