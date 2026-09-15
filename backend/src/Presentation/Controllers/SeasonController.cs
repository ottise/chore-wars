using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/houses/{houseId}/seasons")]
[Authorize]
public class SeasonController : ControllerBase
{
    private readonly ISeasonService _seasonService;

    public SeasonController(ISeasonService seasonService)
    {
        _seasonService = seasonService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpPost]
    public async Task<IActionResult> CreateSeason(Guid houseId, [FromBody] CreateSeasonRequest request, CancellationToken cancellationToken)
    {
        var response = await _seasonService.CreateSeasonAsync(houseId, request, CurrentUserId, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{seasonId}/start")]
    public async Task<IActionResult> StartSeason(Guid seasonId, CancellationToken cancellationToken)
    {
        await _seasonService.StartSeasonAsync(seasonId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpPost("{seasonId}/end")]
    public async Task<IActionResult> EndSeason(Guid seasonId, CancellationToken cancellationToken)
    {
        await _seasonService.EndSeasonAsync(seasonId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpPost("{seasonId}/availability")]
    public async Task<IActionResult> SetAvailability(Guid seasonId, [FromBody] MemberAvailabilityRequest request, CancellationToken cancellationToken)
    {
        await _seasonService.SetAvailabilityAsync(seasonId, request, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpGet("{seasonId}/rankings")]
    public async Task<IActionResult> GetRankings(Guid seasonId, CancellationToken cancellationToken)
    {
        var rankings = await _seasonService.GetRankingsAsync(seasonId, CurrentUserId, cancellationToken);
        return Ok(rankings);
    }
}
