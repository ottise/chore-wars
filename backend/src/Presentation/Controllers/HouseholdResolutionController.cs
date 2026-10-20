using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize,Route("api/occurrences/{occurrenceId:guid}/take-responsibility")]
public class HouseholdResolutionController(IHouseholdResolutionService resolution):ControllerBase {
    [HttpPost] public async Task<IActionResult> Take(Guid occurrenceId,CancellationToken ct) { await resolution.TakeResponsibilityAsync(occurrenceId,Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),ct);return Ok(); }
}
