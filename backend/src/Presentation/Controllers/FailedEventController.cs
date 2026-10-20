using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChoreWars.Presentation.Controllers;

[ApiController, Authorize, Route("api/houses/{houseId:guid}/failed-events")]
public sealed class FailedEventController(IFailedEventService events) : ControllerBase
{
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    [HttpGet]
    public async Task<IActionResult> List(Guid houseId, [FromQuery] string? status, [FromQuery] int page = 1, CancellationToken ct = default)
        => Ok(await events.ListAsync(houseId,UserId,status,page,ct));
    [HttpPost("{failedEventId:guid}/replay")]
    public async Task<IActionResult> Replay(Guid houseId, Guid failedEventId, CancellationToken ct)
    {
        await events.ReplayAsync(houseId,failedEventId,UserId,ct);
        return Accepted();
    }
}
