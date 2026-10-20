using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api")]
public class HouseAdministrationController(IHouseService houses) : ControllerBase {
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    [HttpGet("invitations/{code}/preview")] public async Task<IActionResult> Preview(string code,CancellationToken ct) => Ok(await houses.PreviewInviteAsync(code,ct));
    [HttpPost("houses/{houseId:guid}/transfer-ownership")] public async Task<IActionResult> Transfer(Guid houseId,TransferOwnerRequest request,CancellationToken ct) { await houses.TransferOwnershipAsync(houseId,request.TargetUserId,UserId,ct); return Ok(); }
    [HttpPost("houses/{houseId:guid}/rotate-invite")] public async Task<IActionResult> Rotate(Guid houseId,CancellationToken ct) => Ok(new { inviteCode = await houses.RotateInviteAsync(houseId,UserId,ct) });
    [HttpPost("houses/{houseId:guid}/archive")] public async Task<IActionResult> Archive(Guid houseId,CancellationToken ct) { await houses.ArchiveAsync(houseId,UserId,ct); return Ok(); }
}
public record TransferOwnerRequest(Guid TargetUserId);
