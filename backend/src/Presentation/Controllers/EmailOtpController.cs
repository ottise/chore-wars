using System.ComponentModel.DataAnnotations;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace ChoreWars.Presentation.Controllers;

public sealed record RequestEmailCode([Required, EmailAddress, MaxLength(255)] string Email,
    [Required, MaxLength(32)] string Purpose);
public sealed record VerifyEmailCode([Required, EmailAddress, MaxLength(255)] string Email,
    [Required, RegularExpression("^[0-9]{6}$")] string Code);
public sealed record ResetPasswordCode([Required, EmailAddress, MaxLength(255)] string Email,
    [Required, RegularExpression("^[0-9]{6}$")] string Code, [Required, MinLength(6), MaxLength(128)] string NewPassword);

[ApiController, Route("api/auth"), EnableRateLimiting("email-otp")]
public sealed class EmailOtpController(IEmailOtpService service) : ControllerBase
{
    [HttpPost("email-otp/request")]
    public async Task<IActionResult> RequestCode(RequestEmailCode request, CancellationToken ct)
    {
        await service.RequestAsync(request.Email.Trim(), request.Purpose, ct);
        return Ok(new { message = "If this account is eligible, a code has been sent. Check your email and spam folder." });
    }
    [HttpPost("email-otp/verify")]
    public async Task<IActionResult> Verify(VerifyEmailCode request, CancellationToken ct)
    {
        await service.VerifyAsync(request.Email.Trim(), request.Code, null, ct);
        return Ok(new { message = "Email verified. You can now sign in." });
    }
    [HttpPost("password/reset")]
    public async Task<IActionResult> Reset(ResetPasswordCode request, CancellationToken ct)
    {
        await service.VerifyAsync(request.Email.Trim(), request.Code, request.NewPassword, ct);
        return Ok(new { message = "Password reset. Sign in with your new password." });
    }
}
