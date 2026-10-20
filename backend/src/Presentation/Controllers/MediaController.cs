using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Presentation.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api/media")]
public class MediaController(IMediaService media, IHubContext<ChatHub> hub) : ControllerBase {
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    [HttpPost, RequestSizeLimit(6*1024*1024)]
    public async Task<IActionResult> Upload([FromForm] Guid roomId, IFormFile file, CancellationToken ct) {
        if (file.Length <= 0 || file.Length > 5*1024*1024) return BadRequest("Maximum media size is 5 MB.");
        await using var buffer = new MemoryStream(); await file.CopyToAsync(buffer,ct);
        var result = await media.UploadAsync(roomId,UserId,buffer.ToArray(),ct);
        return Ok(new { result.Id, result.Type, result.DurationSeconds, result.Size });
    }
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Download(Guid id, CancellationToken ct) {
        var result = await media.DownloadAsync(id,UserId,ct);
        Response.Headers.CacheControl = "private, no-store";
        return File(result.Stream,result.Metadata.ContentType,enableRangeProcessing:true);
    }
    [HttpPost("send")]
    public async Task<IActionResult> Send(SendMediaRequest request, CancellationToken ct) {
        var result = await media.SendAsync(request.RoomId,request.AttachmentId,request.ClientMessageId,UserId,ct);
        await hub.Clients.Group(ChatHub.RoomGroup(request.RoomId)).SendAsync("MessageReceived",result,ct);
        return Ok(result);
    }
}
public record SendMediaRequest(Guid RoomId, Guid AttachmentId, Guid ClientMessageId);
