using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.DTOs.AI;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChoreWars.Presentation.Controllers;

[ApiController,Authorize]
public sealed class ChoreEvidenceController(IEvidenceService evidence) : ControllerBase
{
    private Guid Actor=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());
    [HttpPost("api/occurrences/{id:guid}/evidence"),RequestSizeLimit(6_000_000)]
    public async Task<IActionResult> Upload(Guid id,[FromForm]Guid clientRequestId,IFormFile file,CancellationToken ct)
    {
        if (file.Length is <1 or >5_000_000) return BadRequest("Maximum evidence size is 5 MB.");
        using var buffer=new MemoryStream();await file.CopyToAsync(buffer,ct);
        return Ok(await evidence.UploadAsync(id,Actor,clientRequestId,buffer.ToArray(),ct));
    }
    [HttpGet("api/evidence/{id:guid}")]
    public async Task<IActionResult> Read(Guid id,CancellationToken ct)
    {
        var value=await evidence.ReadAsync(id,Actor,ct);Response.Headers.CacheControl="private, no-store";
        return File(value.Stream,value.ContentType);
    }
    [HttpPost("api/occurrences/{id:guid}/ai/verify-proof")]
    public async Task<IActionResult> Verify(Guid id,[FromBody]AIVerifyEvidenceRequest request,CancellationToken ct)=>Ok(await evidence.VerifyAsync(id,request.EvidenceId,Actor,ct));
    [HttpPost("api/occurrences/{id:guid}/evidence/{evidenceId:guid}/attach")]
    public async Task<IActionResult> Save(Guid id,Guid evidenceId,CancellationToken ct) {
        await evidence.SaveAsync(id,evidenceId,Actor,ct);return NoContent();
    }
}
