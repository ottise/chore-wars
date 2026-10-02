using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.DTOs.Chat;

namespace ChoreWars.Presentation.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private readonly IChatService _chatService;

    public ChatHub(IChatService chatService)
    {
        _chatService = chatService;
    }

    private Guid CurrentUserId =>
        Guid.Parse(Context.User!.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    public async Task JoinRoom(Guid roomId)
    {
        // Add to group
        await Groups.AddToGroupAsync(Context.ConnectionId, $"room:{roomId}");
    }

    public async Task LeaveRoom(Guid roomId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"room:{roomId}");
    }

    public async Task SendMessage(Guid roomId, string content)
    {
        // Hub methods do not automatically pass a cancellation token from context.
        var cancellationToken = Context.ConnectionAborted;
        
        var message = await _chatService.CreateMessageAsync(roomId, CurrentUserId, content, cancellationToken);

        await Clients.Group($"room:{roomId}")
            .SendAsync("MessageReceived", message, cancellationToken);
    }
}
