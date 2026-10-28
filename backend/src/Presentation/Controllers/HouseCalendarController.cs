using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api/houses/{houseId:guid}/calendar")]
public sealed class HouseCalendarController(IHouseCalendarService calendar) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Read(Guid houseId, [FromQuery] DateOnly from, [FromQuery] DateOnly to, CancellationToken ct)
    {
        var actor = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());
        return Ok(await calendar.ReadAsync(houseId, actor, from, to, ct));
    }
}
