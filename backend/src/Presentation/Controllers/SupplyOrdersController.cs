using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplyOrdersController(ISupplyOrderService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpGet("api/houses/{houseId:guid}/supply-orders")] public async Task<IActionResult> List(Guid houseId,CancellationToken ct)=>Ok(await service.ListAsync(houseId,Actor,ct));
[HttpGet("api/houses/{houseId:guid}/supply-orders/{id:guid}")] public async Task<IActionResult> Read(Guid houseId,Guid id,CancellationToken ct)=>Ok(await service.ReadAsync(houseId,id,Actor,ct));
[HttpPost("api/houses/{houseId:guid}/supply-orders")] public async Task<IActionResult> Create(Guid houseId,CreateSupplyOrderRequest r,CancellationToken ct)=>Ok(await service.CreateAsync(houseId,Actor,r,ct));
[HttpPut("api/houses/{houseId:guid}/supply-orders/{id:guid}")] public async Task<IActionResult> Revise(Guid houseId,Guid id,ReviseSupplyOrderRequest r,CancellationToken ct)=>Ok(await service.ReviseAsync(houseId,id,Actor,r,ct));
[HttpPost("api/houses/{houseId:guid}/supply-orders/{id:guid}/submit")] public async Task<IActionResult> Submit(Guid houseId,Guid id,SupplyVersionRequest r,CancellationToken ct)=>Ok(await service.SubmitAsync(houseId,id,Actor,r.ExpectedVersion,ct));
[HttpPost("api/houses/{houseId:guid}/supply-orders/{id:guid}/approve")] public async Task<IActionResult> Decide(Guid houseId,Guid id,SupplyDecisionRequest r,CancellationToken ct)=>Ok(await service.DecideAsync(houseId,id,Actor,r,ct));
[HttpPost("api/houses/{houseId:guid}/supply-orders/{id:guid}/cancel")] public async Task<IActionResult> Cancel(Guid houseId,Guid id,SupplyVersionRequest r,CancellationToken ct)=>Ok(await service.CancelAsync(houseId,id,Actor,r.ExpectedVersion,ct));
[HttpPost("api/houses/{houseId:guid}/supply-orders/{id:guid}/receive")] public async Task<IActionResult> Receive(Guid houseId,Guid id,SupplyVersionRequest r,CancellationToken ct)=>Ok(await service.ReceiveAsync(houseId,id,Actor,r.ExpectedVersion,ct));

}
