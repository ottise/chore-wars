using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController, Authorize, Route("api/houses/{houseId:guid}/me")]
public sealed class PersonalFinanceController(IPersonalFinanceService service,IInternalRepaymentService repayments) : ControllerBase
{
    private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    [HttpGet("debts")] public async Task<IActionResult> Debts(Guid houseId,CancellationToken ct) { Response.Headers.CacheControl="private, no-store"; return Ok(await service.DebtsAsync(houseId,Actor,ct)); }
    [HttpGet("debts/{id:guid}")] public async Task<IActionResult> ReadDebt(Guid houseId,Guid id,CancellationToken ct)
    { var debt=await repayments.ReadAsync(id,Actor,ct);if(debt.HouseId!=houseId)throw new ChoreWars.Domain.Exceptions.NotFoundException("Debt not found in this household.");Response.Headers.CacheControl="private, no-store";return Ok(debt); }
    [HttpGet("payment-history")] public async Task<IActionResult> History(Guid houseId,DateOnly from,DateOnly to,CancellationToken ct,string direction="ALL",int page=1,int pageSize=30)
    { Response.Headers.CacheControl="private, no-store"; return Ok(await service.HistoryAsync(houseId,Actor,from,to,direction,page,pageSize,ct)); }
}
