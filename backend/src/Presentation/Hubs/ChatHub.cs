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
    private readonly ChatConnectionRegistry? _connections;
    private readonly IChatService _chatService;

    public ChatHub(IChatService chatService, ChatConnectionRegistry? connections = null)
    {
        _connections = connections;
        _chatService = chatService;
    }

    public static string RoomGroup(Guid roomId) => $"room:{roomId}";

    private Guid CurrentUserId
    {
        get
        {
            var claim = Context.User?.FindFirst(ClaimTypes.NameIdentifier) ?? Context.User?.FindFirst("sub");
            if (claim == null || !Guid.TryParse(claim.Value, out var userId))
            {
                throw new UnauthorizedAccessException("User is not authenticated.");
            }
            return userId;
        }
    }

    public async Task JoinRoom(Guid roomId)
    {
        await _chatService.EnsureRoomAccessAsync(roomId, CurrentUserId, Context.ConnectionAborted);
        await Groups.AddToGroupAsync(Context.ConnectionId, RoomGroup(roomId));
        _connections?.Add(roomId,CurrentUserId,Context.ConnectionId,Context.Abort);
    }

    public override Task OnDisconnectedAsync(Exception? exception) { _connections?.Remove(Context.ConnectionId); return base.OnDisconnectedAsync(exception); }

    public async Task LeaveRoom(Guid roomId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, RoomGroup(roomId));
    }

    public async Task SendMessage(Guid roomId, string content)
    {
        // Hub methods do not automatically pass a cancellation token from context.
        var cancellationToken = Context.ConnectionAborted;
        
        var message = await _chatService.CreateMessageAsync(roomId, CurrentUserId, content, cancellationToken);

        await Clients.Group(RoomGroup(roomId))
            .SendAsync("MessageReceived", message, cancellationToken);
    }
}
