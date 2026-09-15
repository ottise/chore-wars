using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class HouseController : ControllerBase
{
    private readonly IHouseService _houseService;

    public HouseController(IHouseService houseService)
    {
        _houseService = houseService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

    [HttpPost]
    public async Task<IActionResult> CreateHouse([FromBody] CreateHouseRequest request, CancellationToken cancellationToken)
    {
        var response = await _houseService.CreateHouseAsync(request, CurrentUserId, cancellationToken);
        return Ok(response);
    }

    [HttpPost("join")]
    public async Task<IActionResult> JoinHouse([FromBody] JoinHouseRequest request, CancellationToken cancellationToken)
    {
        await _houseService.JoinHouseAsync(request, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpDelete("{houseId}/leave")]
    public async Task<IActionResult> LeaveHouse(Guid houseId, CancellationToken cancellationToken)
    {
        await _houseService.LeaveHouseAsync(houseId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpDelete("{houseId}/members/{memberId}")]
    public async Task<IActionResult> KickMember(Guid houseId, Guid memberId, CancellationToken cancellationToken)
    {
        await _houseService.KickMemberAsync(houseId, memberId, CurrentUserId, cancellationToken);
        return Ok();
    }

    [HttpGet("{houseId}/members")]
    public async Task<IActionResult> GetMembers(Guid houseId, CancellationToken cancellationToken)
    {
        var members = await _houseService.GetMembersAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(members);
    }

    [HttpGet("{houseId}")]
    public async Task<IActionResult> GetHouse(Guid houseId, CancellationToken cancellationToken)
    {
        var house = await _houseService.GetHouseAsync(houseId, CurrentUserId, cancellationToken);
        return Ok(house);
    }

    [HttpGet("my-houses")]
    public async Task<IActionResult> GetUserHouses(CancellationToken cancellationToken)
    {
        var houses = await _houseService.GetUserHousesAsync(CurrentUserId, cancellationToken);
        return Ok(houses);
    }

    [HttpPost("{houseId}/transfer-ownership/{newOwnerId}")]
    public async Task<IActionResult> TransferOwnership(Guid houseId, Guid newOwnerId, CancellationToken cancellationToken)
    {
        await _houseService.TransferOwnershipAsync(houseId, newOwnerId, CurrentUserId, cancellationToken);
        return Ok();
    }
}
