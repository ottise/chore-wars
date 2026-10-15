using System.Security.Claims;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Authorize]
[Route("api/v1")]
public class ActionProposalController : ControllerBase
{
    private readonly IActionProposalService _service;

    public ActionProposalController(IActionProposalService service) => _service = service;

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
        ?? User.FindFirst("sub")?.Value
        ?? throw new UnauthorizedAccessException("User is not authenticated."));

    [HttpPost("houses/{houseId:guid}/proposals")]
    public async Task<IActionResult> Create(Guid houseId, [FromBody] CreateProposalRequest request, CancellationToken cancellationToken)
    {
        var proposal = await _service.CreateProposalAsync(houseId, request, CurrentUserId, cancellationToken);
        return CreatedAtAction(nameof(GetActive), new { roomId = proposal.RoomId }, proposal);
    }

    [HttpPost("proposals/{proposalId:guid}/respond")]
    public async Task<IActionResult> Respond(Guid proposalId, [FromBody] RespondProposalRequest request, CancellationToken cancellationToken)
    {
        var proposal = await _service.RespondProposalAsync(proposalId, request, CurrentUserId, cancellationToken);
        return Ok(proposal);
    }

    [HttpGet("rooms/{roomId:guid}/proposals/active")]
    public async Task<IActionResult> GetActive(Guid roomId, CancellationToken cancellationToken)
    {
        var proposals = await _service.GetActiveProposalsAsync(roomId, CurrentUserId, cancellationToken);
        return Ok(proposals);
    }
}
