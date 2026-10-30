using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.Services;

internal static class ScheduleReviewRevision {
    public static async Task ResetAsync(IUnitOfWork uow, ChoreSeason season, DateTime now, CancellationToken ct) {
        var active = (await uow.HouseMembers.GetByHouseIdAsync(season.HouseId, ct))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE).Select(m => m.UserId).ToHashSet();
        var existing = (await uow.SeasonConfirmations.GetBySeasonIdAsync(season.Id, ct)).ToList();
        foreach (var confirmation in existing) {
            if (!active.Contains(confirmation.UserId)) {
                season.Confirmations.Remove(confirmation);
                uow.SeasonConfirmations.Delete(confirmation);
                continue;
            }
            confirmation.ScheduleRevision = season.ScheduleRevision;
            confirmation.Status = ConfirmationStatus.PENDING;
            confirmation.Reason = null;
            confirmation.UpdatedAt = now;
            uow.SeasonConfirmations.Update(confirmation);
        }
        foreach (var user in active.Where(user => existing.All(c => c.UserId != user)))
            await uow.SeasonConfirmations.AddAsync(new SeasonConfirmation {
                Id = Guid.NewGuid(), SeasonId = season.Id, UserId = user, ScheduleRevision = season.ScheduleRevision,
                Status = ConfirmationStatus.PENDING, CreatedAt = now, UpdatedAt = now
            }, ct);
    }
}
