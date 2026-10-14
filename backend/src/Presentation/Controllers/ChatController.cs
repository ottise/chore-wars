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

    [HttpPost("api/chat/upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadImage([FromForm] Microsoft.AspNetCore.Http.IFormFile file, CancellationToken cancellationToken)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { message = "No file uploaded." });

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
        var ext = System.IO.Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrEmpty(ext) || !System.Array.Exists(allowedExtensions, e => e == ext))
            ext = ".jpg";

        var uploadFolder = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "uploads");
        if (!System.IO.Directory.Exists(uploadFolder))
            System.IO.Directory.CreateDirectory(uploadFolder);

        var fileName = $"{Guid.NewGuid():N}{ext}";
        var filePath = System.IO.Path.Combine(uploadFolder, fileName);

        using (var stream = new System.IO.FileStream(filePath, System.IO.FileMode.Create))
        {
            await file.CopyToAsync(stream, cancellationToken);
        }

        var relativeUrl = $"/uploads/{fileName}";
        var baseUrl = $"{Request.Scheme}://{Request.Host}";
        return Ok(new { url = $"{baseUrl}{relativeUrl}", relativeUrl });
    }
}
