using System.Security.Claims;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplyRefundsController(ISupplyRefundService service):ControllerBase{
 private Guid Actor=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)??User.FindFirstValue("sub")??throw new UnauthorizedAccessException());
 [HttpGet("api/supply-orders/{id:guid}/refunds")]public async Task<IActionResult> List(Guid id,CancellationToken ct)=>Ok(await service.ListAsync(id,Actor,ct));
 [HttpPost("api/supplier/orders/{id:guid}/refunds")]public async Task<IActionResult> Report(Guid id,SupplyRefundRequest r,CancellationToken ct)=>Ok(await service.ReportAsync(id,Actor,r,ct));
 [HttpPost("api/supply-orders/{id:guid}/refunds/{refundId:guid}/confirm")]public async Task<IActionResult> Confirm(Guid id,Guid refundId,CancellationToken ct)=>Ok(await service.ConfirmAsync(id,refundId,Actor,ct));
 [HttpPost("api/supply-orders/{id:guid}/refunds/{refundId:guid}/reject")]public async Task<IActionResult> Reject(Guid id,Guid refundId,CancellationToken ct)=>Ok(await service.RejectAsync(id,refundId,Actor,ct));
}
