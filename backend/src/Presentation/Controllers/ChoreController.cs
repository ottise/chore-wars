using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api")]
[Authorize]
public class ChoreController : ControllerBase
{
    private readonly IChoreService _choreService;

    public ChoreController(IChoreService choreService)
    {
        _choreService = choreService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpPost("houses/{houseId}/chores")]
    public async Task<IActionResult> CreateChore(Guid houseId, [FromBody] CreateChoreRequest request, CancellationToken cancellationToken)
    {
        var response = await _choreService.CreateChoreAsync(houseId, request, CurrentUserId, cancellationToken);
        return Ok(response);
    }

    [HttpPost("occurrences/{occurrenceId}/complete")]
    public async Task<IActionResult> CompleteChore(Guid occurrenceId, CancellationToken cancellationToken)
    {
        await _choreService.CompleteChoreAsync(occurrenceId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpPost("occurrences/{occurrenceId}/skip")]
    public async Task<IActionResult> SkipChore(Guid occurrenceId, CancellationToken cancellationToken)
    {
        await _choreService.SkipChoreAsync(occurrenceId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpGet("houses/{houseId}/my-chores")]
    public async Task<IActionResult> GetMyChores(Guid houseId, CancellationToken cancellationToken)
    {
        var chores = await _choreService.GetMyChoresAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(chores);
    }

    [HttpPut("chores/{choreId}")]
    public async Task<IActionResult> UpdateChore(Guid choreId, [FromBody] UpdateChoreRequest request, CancellationToken cancellationToken)
    {
        var response = await _choreService.UpdateChoreAsync(choreId, request, CurrentUserId, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("chores/{choreId}")]
    public async Task<IActionResult> DeleteChore(Guid choreId, CancellationToken cancellationToken)
    {
        await _choreService.DeleteChoreAsync(choreId, CurrentUserId, cancellationToken);
        return NoContent();
    }

    [HttpGet("houses/{houseId}/chores")]
    public async Task<IActionResult> GetChoresByHouse(Guid houseId, CancellationToken cancellationToken)
    {
        var chores = await _choreService.GetChoresByHouseAsync(houseId, cancellationToken);
        return Ok(chores);
    }

    [HttpPost("chores/{choreId}/assign")]
    public async Task<IActionResult> AssignChore(Guid choreId, [FromBody] AssignChoreRequest request, CancellationToken cancellationToken)
    {
        await _choreService.AssignChoreAsync(choreId, request, CurrentUserId, cancellationToken);
        return Ok();
    }
}
