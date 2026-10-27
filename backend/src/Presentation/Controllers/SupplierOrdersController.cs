using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplierOrdersController(ISupplyCatalogService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpGet("api/supplier/orders")] public async Task<IActionResult> Orders(CancellationToken ct)=>Ok(await service.OrdersAsync(Actor,ct));
[HttpPost("api/supplier/orders/{id:guid}/fulfillment")] public async Task<IActionResult> Fulfill(Guid id,[FromQuery]string status,SupplyVersionRequest r,CancellationToken ct)=>Ok(await service.FulfillAsync(Actor,id,status,r.ExpectedVersion,ct));

}
