using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize,Route("api/occurrences/{occurrenceId:guid}/claim")]
public class ChoreClaimController(IChoreService chores):ControllerBase {
    [HttpPost] public async Task<IActionResult> Claim(Guid occurrenceId,CancellationToken ct){await chores.ClaimBonusAsync(occurrenceId,Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),ct);return Ok();}
}
