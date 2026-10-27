using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplySchedulesController(ISupplyReminderService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpGet("api/houses/{houseId:guid}/supply-schedules")] public async Task<IActionResult> List(Guid houseId,CancellationToken ct)=>Ok(await service.ListAsync(houseId,Actor,ct));
[HttpPost("api/houses/{houseId:guid}/supply-schedules")] public async Task<IActionResult> Create(Guid houseId,CreateSupplyScheduleRequest r,CancellationToken ct)=>Ok(await service.CreateAsync(houseId,Actor,r,ct));
[HttpPatch("api/houses/{houseId:guid}/supply-schedules/{id:guid}")] public async Task<IActionResult> Update(Guid houseId,Guid id,UpdateSupplyScheduleRequest r,CancellationToken ct)=>Ok(await service.UpdateAsync(houseId,id,Actor,r,ct));

}
