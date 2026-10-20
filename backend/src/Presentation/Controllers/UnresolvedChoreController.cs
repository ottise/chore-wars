using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize,Route("api/houses/{houseId:guid}/unresolved-chores")]
public class UnresolvedChoreController(IHouseholdResolutionService resolution):ControllerBase {
    [HttpGet] public async Task<IActionResult> List(Guid houseId,CancellationToken ct)=>Ok(await resolution.ListAsync(houseId,Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),ct));
}
