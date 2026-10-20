using System.Security.Claims;
using ChoreWars.Application.DTOs.Gamification;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api/houses/{houseId:guid}/rewards")]
public class RewardController(IRewardService rewards) : ControllerBase {
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    [HttpGet] public async Task<IActionResult> List(Guid houseId,CancellationToken ct) => Ok(await rewards.ListAsync(houseId,UserId,ct));
    [HttpPost] public async Task<IActionResult> Create(Guid houseId,CreateRewardRequest request,CancellationToken ct) => Ok(await rewards.CreateAsync(houseId,request,UserId,ct));
    [HttpPut("{rewardId:guid}")] public async Task<IActionResult> Update(Guid houseId,Guid rewardId,UpdateRewardRequest request,CancellationToken ct) => Ok(await rewards.UpdateAsync(houseId,rewardId,request,UserId,ct));
    [HttpPost("{rewardId:guid}/redeem")] public async Task<IActionResult> Redeem(Guid houseId,Guid rewardId,RedeemRequest request,CancellationToken ct) { await rewards.RedeemAsync(houseId,rewardId,request.ClientRequestId,UserId,ct); return Ok(); }
}
public record RedeemRequest(Guid ClientRequestId);
