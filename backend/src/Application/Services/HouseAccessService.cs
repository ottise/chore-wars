using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public sealed class HouseAccessService(IUnitOfWork uow) : IHouseAccessService {
    public async Task EnsureWritableAsync(Guid houseId, CancellationToken ct) {
        var house = await uow.Houses.GetByIdAsync(houseId,ct) ?? throw new NotFoundException("Household not found.");
        if (house.IsArchived) throw new ConflictException("Archived households are read-only.");
    }
    public async Task EnsureActiveAsync(Guid houseId, Guid userId, CancellationToken ct) {
        var member = await uow.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
        if (member?.Status != HouseMemberStatus.ACTIVE) throw new ForbiddenException("Active household membership is required.");
    }
    public async Task EnsureEntityScopeAsync(Guid houseId, string kind, Guid entityId, CancellationToken ct) {
        Guid? actual = kind switch {
            "seasonId" => (await uow.Seasons.GetByIdAsync(entityId,ct))?.HouseId,
            "choreId" => (await uow.Chores.GetByIdAsync(entityId,ct))?.HouseId,
            "occurrenceId" => (await uow.ChoreOccurrences.GetByIdAsync(entityId,ct))?.Chore.HouseId,
            "paymentId" => (await uow.PaymentObligations.GetByIdAsync(entityId,ct))?.HouseId,
            "bountyId" => (await uow.ChoreBounties.GetByIdAsync(entityId,ct))?.ChoreOccurrence.Chore.HouseId,
            _ => houseId
        };
        if (actual != houseId) throw new NotFoundException("Resource not found in this household.");
    }
}
