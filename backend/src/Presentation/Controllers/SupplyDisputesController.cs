using System.Security.Claims;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplyDisputesController(ISupplyDisputeService service):ControllerBase{
 private Guid Actor=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)??User.FindFirstValue("sub")??throw new UnauthorizedAccessException());
 [HttpGet("api/supply-orders/{id:guid}/disputes")]public async Task<IActionResult> List(Guid id,CancellationToken ct)=>Ok(await service.ListAsync(id,Actor,ct));
 [HttpPost("api/supply-orders/{id:guid}/disputes")]public async Task<IActionResult> Create(Guid id,CreateSupplyDisputeRequest r,CancellationToken ct)=>Ok(await service.CreateAsync(id,Actor,r,ct));
 [HttpPost("api/supplier/orders/{id:guid}/disputes/{disputeId:guid}/propose")]public async Task<IActionResult> Propose(Guid id,Guid disputeId,ProposeSupplyResolutionRequest r,CancellationToken ct)=>Ok(await service.ProposeAsync(id,disputeId,Actor,r,ct));
 [HttpPost("api/supply-orders/{id:guid}/disputes/{disputeId:guid}/accept")]public async Task<IActionResult> Accept(Guid id,Guid disputeId,CancellationToken ct)=>Ok(await service.AcceptAsync(id,disputeId,Actor,ct));
}
