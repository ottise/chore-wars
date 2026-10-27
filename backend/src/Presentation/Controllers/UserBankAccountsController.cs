using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class UserBankAccountsController(IUserBankAccountService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpGet("api/user/bank-account")] public async Task<IActionResult> Read(CancellationToken ct){Response.Headers.CacheControl="private, no-store";return Ok(await service.ReadAsync(Actor,ct));}
[HttpPut("api/user/bank-account")] public async Task<IActionResult> Save(UpsertBankAccountRequest r,CancellationToken ct)=>Ok(await service.SaveAsync(Actor,r,ct));

}
