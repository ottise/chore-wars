using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Presentation.Controllers;

[ApiController, Authorize, Route("api/houses/{houseId:guid}/members/{userId:guid}")]
public sealed class HouseMemberReadController(AppDbContext db, IHouseAccessService access, IAvatarStorage avatars) : ControllerBase
{
    private Guid Actor => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    private async Task Check(Guid houseId, Guid userId, CancellationToken ct)
    {
        await access.EnsureActiveAsync(houseId, Actor, ct);
        if (!await db.HouseMembers.AnyAsync(m => m.HouseId == houseId && m.UserId == userId, ct)) throw new NotFoundException("Member not found in this household.");
    }
    [HttpGet("avatar")]
    public async Task<IActionResult> Avatar(Guid houseId, Guid userId, CancellationToken ct)
    {
        await Check(houseId, userId, ct); Response.Headers.CacheControl = "private, no-store";
        var url = await db.Users.Where(u => u.Id == userId).Select(u => u.AvatarUrl).SingleAsync(ct);
        if (string.IsNullOrWhiteSpace(url)) return NoContent();
        try { var image = await avatars.ReadAsync(url, ct); return File(image.Stream, image.ContentType); }
        catch (NotFoundException) { return NoContent(); }
    }
    [HttpGet("schedule")]
    public async Task<IActionResult> Schedule(Guid houseId, Guid userId, [FromQuery] DateOnly from, [FromQuery] DateOnly to,
        [FromQuery] Guid? season, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken ct = default)
    {
        await Check(houseId, userId, ct); var range = PersonalFinanceService.Range(from, to);
        if (page < 1 || page > 100000 || pageSize < 1 || pageSize > 100) throw new DomainException("Invalid page.");
        if (season.HasValue && !await db.Seasons.AnyAsync(s => s.Id == season && s.HouseId == houseId, ct)) throw new NotFoundException("Season not found in this household.");
        var query = db.ChoreOccurrences.AsNoTracking().Where(o => o.Chore.HouseId == houseId && (o.Season.Status == ChoreWars.Domain.Enums.SeasonStatus.ACTIVE || o.Season.Status == ChoreWars.Domain.Enums.SeasonStatus.COMPLETED) && (o.AssignedUserId == userId || o.CompletedByUserId == userId) &&
            (!season.HasValue || o.SeasonId == season) && o.DueDate >= range.From && o.DueDate < range.To);
        var total = await query.CountAsync(ct);
        var rows = await query.OrderBy(o => o.DueDate).ThenBy(o => o.Id).Skip((page - 1) * pageSize).Take(pageSize).Select(o => new
        {
            o.Id,
            ChoreName = o.Chore.Name,
            o.AssignedUserId,
            o.CompletedByUserId,
            o.DueDate,
            o.CompletedAt,
            o.Status,
            o.EvidenceId,
            o.SeasonId,
            AssignedUserDisplayName = o.AssignedUser == null ? null : o.AssignedUser.DisplayName
        }).ToListAsync(ct);
        return Ok(new { total, page, pageSize, items = rows });
    }
}
