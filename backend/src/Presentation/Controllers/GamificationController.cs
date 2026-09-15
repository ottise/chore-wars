using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/houses/{houseId}/gamification")]
[Authorize]
public class GamificationController : ControllerBase
{
    private readonly IGamificationService _gamificationService;

    public GamificationController(IGamificationService gamificationService)
    {
        _gamificationService = gamificationService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpGet("karma")]
    public async Task<IActionResult> GetKarmaBalance(Guid houseId, CancellationToken cancellationToken)
    {
        var karma = await _gamificationService.GetKarmaBalanceAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(new { Karma = karma });
    }

    [HttpGet("seasons/{seasonId}/rewards")]
    public async Task<IActionResult> GetSeasonRewards(Guid houseId, Guid seasonId, CancellationToken cancellationToken)
    {
        var rewards = await _gamificationService.GetSeasonRewardsAsync(seasonId, CurrentUserId, cancellationToken);
        return Ok(rewards);
    }

    [HttpPost("rewards/{rewardId}/use-chore-pass/{occurrenceId}")]
    public async Task<IActionResult> UseChorePass(Guid houseId, Guid rewardId, Guid occurrenceId, CancellationToken cancellationToken)
    {
        await _gamificationService.UseChorePassAsync(rewardId, occurrenceId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpGet("achievements")]
    public async Task<IActionResult> GetAchievements(Guid houseId, CancellationToken cancellationToken)
    {
        var achievements = await _gamificationService.GetAchievementsAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(achievements);
    }
}
