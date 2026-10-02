using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.DTOs.Chat;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly IChatService _chatService;

    public ChatController(IChatService chatService)
    {
        _chatService = chatService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpGet("api/houses/{houseId}/chat")]
    public async Task<IActionResult> GetRoom(Guid houseId, CancellationToken cancellationToken)
    {
        var room = await _chatService.GetHouseRoomAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(room);
    }

    [HttpGet("api/chat/rooms/{roomId}/messages")]
    public async Task<IActionResult> GetMessages(
        Guid roomId, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken cancellationToken = default)
    {
        var result = await _chatService.GetMessagesAsync(roomId, CurrentUserId, page, pageSize, cancellationToken);
        return Ok(result);
    }
}
