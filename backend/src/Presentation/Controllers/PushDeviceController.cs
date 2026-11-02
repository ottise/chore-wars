using System.Security.Claims;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/push-devices")]
[Authorize]
public sealed class PushDeviceController(IPushDeviceService pushDevices) : ControllerBase
{
    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpPost]
    public async Task<IActionResult> Register(PushDeviceRequest request, CancellationToken cancellationToken)
    {
        await pushDevices.RegisterAsync(CurrentUserId, request.Token, request.Platform, cancellationToken);
        return NoContent();
    }

    [HttpDelete]
    public async Task<IActionResult> Revoke(PushDeviceRequest request, CancellationToken cancellationToken)
    {
        await pushDevices.RevokeAsync(CurrentUserId, request.Token, cancellationToken);
        return NoContent();
    }
}
