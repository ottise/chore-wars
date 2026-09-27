using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.DTOs.Bounty;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/houses/{houseId}/bounties")]
[Authorize]
public class BountyController : ControllerBase
{
    private readonly IBountyService _bountyService;

    public BountyController(IBountyService bountyService)
    {
        _bountyService = bountyService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpPost]
    public async Task<IActionResult> CreateBounty(Guid houseId, [FromBody] CreateBountyRequest request, CancellationToken cancellationToken)
    {
        var response = await _bountyService.CreateBountyAsync(houseId, request, CurrentUserId, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{bountyId}/accept")]
    public async Task<IActionResult> AcceptBounty(Guid houseId, Guid bountyId, CancellationToken cancellationToken)
    {
        await _bountyService.AcceptBountyAsync(bountyId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpGet]
    public async Task<IActionResult> GetBounties(Guid houseId, CancellationToken cancellationToken)
    {
        var bounties = await _bountyService.GetBountiesAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(bounties);
    }

    [HttpGet("{bountyId}")]
    public async Task<IActionResult> GetBounty(Guid houseId, Guid bountyId, CancellationToken cancellationToken)
    {
        var bounty = await _bountyService.GetBountyAsync(houseId, bountyId, CurrentUserId, cancellationToken);
        return Ok(bounty);
    }

    [HttpGet("payments")]
    public async Task<IActionResult> GetPayments(Guid houseId, CancellationToken cancellationToken)
    {
        var payments = await _bountyService.GetPaymentsAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(payments);
    }

    [HttpGet("payments/{paymentId}")]
    public async Task<IActionResult> GetPayment(Guid houseId, Guid paymentId, CancellationToken cancellationToken)
    {
        var payment = await _bountyService.GetPaymentAsync(houseId, paymentId, CurrentUserId, cancellationToken);
        return Ok(payment);
    }

    [HttpPost("payments/{paymentId}/settle")]
    public async Task<IActionResult> SettlePayment(Guid houseId, Guid paymentId, CancellationToken cancellationToken)
    {
        await _bountyService.SettlePaymentAsync(paymentId, CurrentUserId, cancellationToken);
        return Ok();
    }
}
