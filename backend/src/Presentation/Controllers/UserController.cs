using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.DTOs.User;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/user")]
[Authorize]
public class UserController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IAvatarStorage _avatars;

    public UserController(IAuthService authService, IAvatarStorage avatars)
    {
        _authService = authService;
        _avatars = avatars;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpGet("profile")]
    public async Task<IActionResult> GetProfile(CancellationToken cancellationToken)
    {
        var profile = await _authService.GetProfileAsync(CurrentUserId, cancellationToken);
        return Ok(profile);
    }

    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        var profile = await _authService.UpdateProfileAsync(CurrentUserId, request, cancellationToken);
        return Ok(profile);
    }

    [HttpGet("avatar-image")]
    public async Task<IActionResult> ReadAvatar(CancellationToken cancellationToken)
    {
        var profile = await _authService.GetProfileAsync(CurrentUserId, cancellationToken);
        if (string.IsNullOrWhiteSpace(profile.AvatarUrl)) return NotFound();
        var image = await _avatars.ReadAsync(profile.AvatarUrl, cancellationToken);
        Response.Headers.CacheControl = "private, no-store";
        return File(image.Stream, image.ContentType);
    }

    [HttpPost("avatar")]
    public async Task<IActionResult> UploadAvatar(Microsoft.AspNetCore.Http.IFormFile file, CancellationToken cancellationToken)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { Message = "File is empty" });

        var ext = System.IO.Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp")
            return BadRequest(new { Message = "Only JPG, PNG, and WebP are allowed" });

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { Message = "File size must be under 5MB" });

        using var buffer = new System.IO.MemoryStream();
        await file.CopyToAsync(buffer, cancellationToken);
        var avatarUrl = await _avatars.WriteAsync(buffer.ToArray(), ext, cancellationToken);
        var profile = await _authService.UpdateAvatarUrlAsync(CurrentUserId, avatarUrl, cancellationToken);
        return Ok(profile);
    }
}
