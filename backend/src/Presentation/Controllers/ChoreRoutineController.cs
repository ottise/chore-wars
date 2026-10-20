using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize,Route("api/houses/{houseId:guid}/seasons/{seasonId:guid}/routines")]
public class ChoreRoutineController(IChoreService chores) : ControllerBase {
    [HttpPost("{templateId:guid}")]
    public async Task<IActionResult> Import(Guid houseId, Guid seasonId, Guid templateId, CancellationToken ct) => Ok(await chores.ImportRoutineAsync(houseId,seasonId,templateId,Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),ct));
}
