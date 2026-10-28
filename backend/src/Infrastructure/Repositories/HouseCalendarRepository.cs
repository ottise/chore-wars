using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Infrastructure.Repositories;
public sealed class HouseCalendarRepository(AppDbContext db) : IHouseCalendarRepository
{
    public async Task<List<HouseCalendarItemResponse>> ReadAsync(Guid house, DateTime fromUtc, DateTime toExclusiveUtc, CancellationToken ct)
    {
        var rows = await db.ChoreOccurrences.AsNoTracking().Where(o => o.Chore.HouseId == house &&
            ((o.DueDate >= fromUtc && o.DueDate < toExclusiveUtc) || (o.CompletedAt >= fromUtc && o.CompletedAt < toExclusiveUtc)))
            .OrderBy(o => o.DueDate).Select(o => new { o.Id, o.Chore.Name, o.Status, o.Chore.Type, o.DueDate, o.CompletedAt,
                o.AssignedUserId, AssignedName = o.AssignedUser == null ? null : o.AssignedUser.DisplayName,
                o.CompletedByUserId, CompletedName = db.Users.Where(u => u.Id == o.CompletedByUserId).Select(u => u.DisplayName).FirstOrDefault() }).ToListAsync(ct);
        var ids = rows.Where(x => x.Status == ChoreOccurrenceStatus.COMPLETED).Select(x => x.Id).ToList();
        var photos = await db.ChoreEvidence.AsNoTracking().Where(e => e.HouseId == house && ids.Contains(e.OccurrenceId) && e.AttachedAt != null)
            .OrderBy(e => e.AttachedAt).ThenBy(e => e.Id).Select(e => new { e.OccurrenceId, e.Id }).ToListAsync(ct);
        var grouped = photos.ToLookup(e => e.OccurrenceId, e => e.Id);
        return rows.Select(x => new HouseCalendarItemResponse(x.Id, x.Name, x.Status.ToString(), x.Type.ToString(), x.DueDate,
            x.CompletedAt, x.AssignedUserId, x.AssignedName, x.CompletedByUserId, x.CompletedName, grouped[x.Id].Distinct().ToList())).ToList();
    }
}
