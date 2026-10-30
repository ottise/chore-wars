using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.DTOs.Auth;
using System.Threading;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IGoogleAuthService _googleAuth;

    public AuthController(IAuthService authService, IGoogleAuthService googleAuth)
    {
        _authService = authService;
        _googleAuth = googleAuth;
    }

    [HttpPost("google")]
    [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("google-auth")]
    public async Task<IActionResult> GoogleLogin([FromBody] GoogleLoginRequest request, CancellationToken cancellationToken) =>
        Ok(await _googleAuth.LoginAsync(request, cancellationToken));

    [Authorize]
    [HttpPost("google/link")]
    [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("google-auth")]
    public async Task<IActionResult> LinkGoogle([FromBody] GoogleLoginRequest request, CancellationToken cancellationToken)
    {
        var userId = System.Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        await _googleAuth.LinkAsync(userId, request, cancellationToken);
        return Ok(new { Message = "Google account linked." });
    }

    [HttpPost("register")]
    [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("password-auth")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request, CancellationToken cancellationToken)
    {
        await _authService.RegisterAsync(request, cancellationToken);
        return Ok(new { Message = "Registration successful." });
    }

    [HttpPost("login")]
    [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("password-auth")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        var response = await _authService.LoginAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("refresh-token")]
    [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("password-auth")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var response = await _authService.RefreshTokenAsync(request, cancellationToken);
        return Ok(response);
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken cancellationToken)
    {
        var userId = System.Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        await _authService.LogoutAsync(userId, cancellationToken);
        return Ok(new { Message = "Logged out successfully." });
    }
}
