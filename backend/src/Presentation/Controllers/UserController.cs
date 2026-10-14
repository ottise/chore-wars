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

    public UserController(IAuthService authService)
    {
        _authService = authService;
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

        var uploadsFolder = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "avatars");
        if (!System.IO.Directory.Exists(uploadsFolder))
            System.IO.Directory.CreateDirectory(uploadsFolder);

        var uniqueFileName = Guid.NewGuid().ToString() + ext;
        var filePath = System.IO.Path.Combine(uploadsFolder, uniqueFileName);

        using (var stream = new System.IO.FileStream(filePath, System.IO.FileMode.Create))
        {
            await file.CopyToAsync(stream, cancellationToken);
        }

        var avatarUrl = $"/avatars/{uniqueFileName}";
        var profile = await _authService.UpdateAvatarUrlAsync(CurrentUserId, avatarUrl, cancellationToken);
        return Ok(profile);
    }
}
