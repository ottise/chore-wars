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
    private readonly IChatReadService _read;

    public ChatController(IChatService chatService, IChatReadService read)
    {
        _chatService = chatService;
        _read = read;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    public record ReadRequest(Guid MessageId);
    [HttpGet("api/houses/{houseId}/chat/unread")]
    public async Task<IActionResult> Unread(Guid houseId, CancellationToken ct) => Ok(new { count = await _read.UnreadAsync(houseId, CurrentUserId, ct) });
    [HttpPut("api/houses/{houseId}/chat/read")]
    public async Task<IActionResult> Read(Guid houseId, ReadRequest request, CancellationToken ct)
    {
        await _read.ReadAsync(houseId, CurrentUserId, request.MessageId, ct); return NoContent();
    }

    [HttpGet("api/houses/{houseId}/chat/notification-settings")]
    public async Task<IActionResult> GetNotificationSettings(Guid houseId, CancellationToken cancellationToken)
        => Ok(new { enabled = await _chatService.GetNotificationsEnabledAsync(houseId, CurrentUserId, cancellationToken) });

    [HttpPut("api/houses/{houseId}/chat/notification-settings")]
    public async Task<IActionResult> SetNotificationSettings(Guid houseId, ChatNotificationSettingsRequest request, CancellationToken cancellationToken)
    {
        await _chatService.SetNotificationsEnabledAsync(houseId, CurrentUserId, request.Enabled!.Value, cancellationToken);
        return NoContent();
    }

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

    [HttpGet("api/chat/rooms/{roomId:guid}/photos")]
    public async Task<IActionResult> Photos(Guid roomId, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken ct = default)
        => Ok(await _chatService.GetImagesAsync(roomId, CurrentUserId, page, pageSize, ct));

}
