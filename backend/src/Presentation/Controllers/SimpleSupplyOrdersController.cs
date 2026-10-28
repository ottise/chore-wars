using System.Security.Claims;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api/houses/{houseId:guid}/orders")]
public sealed class SimpleSupplyOrdersController(ISimpleSupplyOrderService service) : ControllerBase
{
    private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());
    [HttpPost("send")]
    public async Task<IActionResult> Send(Guid houseId, SendSupplyOrderRequest request, CancellationToken ct) => Ok(await service.SendAsync(houseId, Actor, request, ct));
    [HttpPost("{orderId:guid}/retry-email")]
    public async Task<IActionResult> Retry(Guid houseId, Guid orderId, CancellationToken ct) => Ok(await service.RetryEmailAsync(houseId, orderId, Actor, ct));
    [HttpPost("{orderId:guid}/record-payment")]
    public async Task<IActionResult> Record(Guid houseId, Guid orderId, RecordSupplyOrderPaymentRequest request, CancellationToken ct) => Ok(await service.RecordPaymentAsync(houseId, orderId, Actor, request, ct));
}
