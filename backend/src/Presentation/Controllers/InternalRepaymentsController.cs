using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class InternalRepaymentsController(IInternalRepaymentService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpGet("api/houses/{houseId:guid}/purchase-debts")] public async Task<IActionResult> Summary(Guid houseId,CancellationToken ct)=>Ok(await service.SummaryAsync(houseId,Actor,ct));
[HttpGet("api/payment-obligations/{id:guid}/purchase-debt")] public async Task<IActionResult> Read(Guid id,CancellationToken ct)=>Ok(await service.ReadAsync(id,Actor,ct));
[HttpGet("api/payment-obligations/{id:guid}/instructions")] public async Task<IActionResult> Instructions(Guid id,CancellationToken ct){Response.Headers.CacheControl="private, no-store";return Ok(await service.InstructionsAsync(id,Actor,ct));}
[HttpPost("api/payment-obligations/{id:guid}/repayments")] public async Task<IActionResult> Report(Guid id,ReportRepaymentRequest r,CancellationToken ct)=>Ok(await service.ReportAsync(id,Actor,r,ct));
[HttpGet("api/payment-obligations/{id:guid}/debt")] public async Task<IActionResult> GenericRead(Guid id,CancellationToken ct)=>Ok(await service.ReadAsync(id,Actor,ct));
[HttpPost("api/payment-obligations/{id:guid}/record-receipt")] public async Task<IActionResult> Receipt(Guid id,ReportRepaymentRequest r,CancellationToken ct)=>Ok(await service.RecordReceiptAsync(id,Actor,r,ct));
[HttpPost("api/payment-obligations/{id:guid}/repayments/{repaymentId:guid}/respond")] public async Task<IActionResult> Respond(Guid id,Guid repaymentId,ConfirmRepaymentRequest r,CancellationToken ct)=>Ok(await service.RespondAsync(id,repaymentId,Actor,r,ct));

}
