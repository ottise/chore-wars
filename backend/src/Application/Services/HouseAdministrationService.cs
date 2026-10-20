using ChoreWars.Application.DTOs.House;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public partial class HouseService {
    private async Task InvalidateAllocationInputsAsync(Guid houseId, CancellationToken ct) {
        var season = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId,ct);
        if (season?.Status == SeasonStatus.REVIEWING)
            throw new ConflictException("Reject the current review before changing allocation preferences or capacity.");
        if (season?.Status != SeasonStatus.DRAFT) return;
        season.ScheduleRevision++;
        _unitOfWork.Seasons.Update(season);
        await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(season.Id,ct);
        if (season.AllocationMethod == AllocationMethod.AUTOMATIC)
            await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(season.Id,ct);
    }
    private async Task RevokeRoomAsync(Guid houseId, Guid userId, CancellationToken ct) {
        var room = await _unitOfWork.Chats.GetRoomByHouseIdAsync(houseId,ct);
        if (room != null) _realtimeAccess?.Revoke(room.Id,userId);
    }
    private async Task InvalidateReviewAsync(Guid houseId, CancellationToken ct) {
        var season = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId,ct);
        if (season?.Status == SeasonStatus.REVIEWING) {
            season.Status = SeasonStatus.DRAFT; season.ScheduleRevision++;
            _unitOfWork.Seasons.Update(season);
            await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(season.Id,ct);
        }
    }
    private async Task OwnerAsync(Guid houseId, Guid userId, CancellationToken ct) {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
        if (member?.Status != HouseMemberStatus.ACTIVE || member.Role != HouseRole.OWNER) throw new ForbiddenException("Only the active owner can perform this action.");
    }
    public async Task<InvitePreviewResponse> PreviewInviteAsync(string code, CancellationToken ct = default) {
        var house = await _unitOfWork.Houses.GetByInviteCodeAsync(code,ct) ?? throw new NotFoundException("Invitation not found.");
        if (house.IsArchived) throw new ConflictException("Household archived.");
        var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(house.Id,ct);
        return new(house.Name,members.Count(m => m.Status == HouseMemberStatus.ACTIVE),6);
    }
    public async Task<string> RotateInviteAsync(Guid houseId, Guid userId, CancellationToken ct = default) {
        async Task<string> Apply() {
            await OwnerAsync(houseId,userId,ct);
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId,ct) ?? throw new NotFoundException("Household not found.");
            house.InviteCode = await GenerateUniqueInviteCodeAsync(ct); house.InviteVersion++;
            _unitOfWork.Houses.Update(house); await _unitOfWork.SaveChangesAsync(ct); return house.InviteCode;
        }
        return _mutations != null ? await _mutations.RunAsync(houseId,Apply,ct) : await Apply();
    }
    public async Task ArchiveAsync(Guid houseId, Guid userId, CancellationToken ct = default) {
        async Task Apply() {
            await OwnerAsync(houseId,userId,ct);
            if (await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId,ct) != null) throw new ConflictException("Finish or cancel the current season first.");
            var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(houseId,ct);
            foreach (var member in members) {
                await EnsureNoOpenObligationsAsync(houseId,member.UserId,ct);
                var chores = await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(member.UserId,ct);
                if (chores.Any(o => o.Chore.HouseId == houseId && o.Status is ChoreOccurrenceStatus.ASSIGNED or ChoreOccurrenceStatus.OVERDUE or ChoreOccurrenceStatus.CRITICAL_OVERDUE)) throw new ConflictException("Resolve outstanding responsibilities first.");
            }
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId,ct) ?? throw new NotFoundException("Household not found.");
            house.IsArchived = true; _unitOfWork.Houses.Update(house); await _unitOfWork.SaveChangesAsync(ct);
        }
        if (_mutations != null) await _mutations.RunAsync(houseId,Apply,ct); else await Apply();
    }
}
