using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplierPaymentsController(ISupplierPaymentService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpPost("api/houses/{houseId:guid}/supply-orders/{id:guid}/checkout")] public async Task<IActionResult> Checkout(Guid houseId,Guid id,SupplyVersionRequest r,CancellationToken ct)=>Ok(await service.CheckoutAsync(houseId,id,Actor,r.ExpectedVersion,ct));
[HttpGet("api/houses/{houseId:guid}/supply-orders/{id:guid}/payment")] public async Task<IActionResult> Refresh(Guid houseId,Guid id,CancellationToken ct)=>Ok(await service.RefreshAsync(houseId,id,Actor,ct));
[AllowAnonymous,HttpPost("api/payments/webhooks/payos"),RequestSizeLimit(64000)] public async Task<IActionResult> Webhook(JsonElement payload,CancellationToken ct){await service.WebhookAsync(payload,ct);return Ok();}

}
