using ChoreWars.Application.DTOs.House;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public partial class HouseService {
    private async Task InvalidateAllocationInputsAsync(Guid houseId, CancellationToken ct) {
        var season = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId,ct);
        if (season == null) return;
        if (season.Status is not (SeasonStatus.DRAFT or SeasonStatus.REVIEWING)) return;
        season.Status = SeasonStatus.DRAFT;
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
    public async Task DeleteHouseAsync(Guid houseId, Guid userId, CancellationToken ct = default) {
        async Task Apply() {
            await OwnerAsync(houseId,userId,ct);
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId,ct) ?? throw new NotFoundException("Household not found.");
            if (house.IsArchived) return;
            var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(houseId,ct)).Where(m => m.Status == HouseMemberStatus.ACTIVE).ToList();
            await _unitOfWork.BeginTransactionAsync(ct);
            try {
                foreach (var season in await _unitOfWork.Seasons.GetByHouseIdAsync(houseId,ct)) {
                    if (season.Status is SeasonStatus.COMPLETED or SeasonStatus.CANCELLED) continue;
                    season.Status = SeasonStatus.CANCELLED;
                    season.ScheduleRevision++;
                    _unitOfWork.Seasons.Update(season);
                    await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(season.Id,ct);
                }
                house.IsArchived = true;
                house.InviteVersion++;
                _unitOfWork.Houses.Update(house);
                await _unitOfWork.SaveChangesAsync(ct);
                await _unitOfWork.CommitTransactionAsync(ct);
            } catch {
                await _unitOfWork.RollbackTransactionAsync(ct);
                throw;
            }
            foreach (var member in members) await RevokeRoomAsync(houseId,member.UserId,ct);
        }
        if (_mutations != null) await _mutations.RunAsync(houseId,Apply,ct); else await Apply();
    }
    public async Task UpdateHouseNameAsync(Guid houseId, UpdateHouseNameRequest request, Guid userId, CancellationToken ct = default) {
        async Task Apply() {
            var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
            if (member?.Status != HouseMemberStatus.ACTIVE) throw new ForbiddenException("Only active household members can rename the household.");
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId,ct) ?? throw new NotFoundException("Household not found.");
            if (house.IsArchived) throw new ConflictException("Archived households are read-only.");
            var name = request.Name.Trim();
            if (string.IsNullOrWhiteSpace(name) || name.Length > 100) throw new DomainException("Household name must be between 1 and 100 characters.");
            if (house.Name == name) return;
            house.Name = name;
            _unitOfWork.Houses.Update(house);
            await _unitOfWork.SaveChangesAsync(ct);
        }
        if (_mutations != null) await _mutations.RunAsync(houseId,Apply,ct); else await Apply();
    }
}
