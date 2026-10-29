using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api/houses/{houseId:guid}/summary")]
public sealed class HouseholdSummaryController(IHouseholdSummaryService service) : ControllerBase
{
    [HttpGet] public async Task<IActionResult> Read(Guid houseId,DateOnly from,DateOnly to,CancellationToken ct,Guid? seasonId=null)
    { Response.Headers.CacheControl="private, no-store"; return Ok(await service.ReadAsync(houseId,Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),from,to,seasonId,ct)); }
}
