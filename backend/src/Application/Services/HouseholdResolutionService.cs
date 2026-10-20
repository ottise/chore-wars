using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public sealed class HouseholdResolutionService(IUnitOfWork uow,IHouseMutationCoordinator mutations,IOverduePenaltyService penalties,TimeProvider clock, AutoMapper.IMapper mapper) : IHouseholdResolutionService {
    public async Task<IReadOnlyList<ChoreWars.Application.DTOs.Chore.ChoreOccurrenceResponse>> ListAsync(Guid houseId, Guid userId, CancellationToken ct) {
        var member=await uow.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
        if(member?.Status!=HouseMemberStatus.ACTIVE)throw new ForbiddenException();
        var occurrences=await uow.ChoreOccurrences.GetUnresolvedByHouseIdAsync(houseId,ct);
        return mapper.Map<List<ChoreWars.Application.DTOs.Chore.ChoreOccurrenceResponse>>(occurrences);
    }
    public async Task TakeResponsibilityAsync(Guid occurrenceId, Guid userId, CancellationToken ct) {
        var original=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct)??throw new NotFoundException("Occurrence not found.");
        await mutations.RunAsync(original.Chore.HouseId,async()=>{
            var occurrence=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct)??throw new NotFoundException("Occurrence not found.");
            var member=await uow.HouseMembers.GetByHouseAndUserIdAsync(occurrence.Chore.HouseId,userId,ct);
            if(member?.Status!=HouseMemberStatus.ACTIVE)throw new ForbiddenException();
            var now=clock.GetUtcNow().UtcDateTime;
            var season=await uow.Seasons.GetByIdAsync(occurrence.SeasonId,ct);
            if(season==null||season.Status is SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.CANCELLED||now<season.StartDate)throw new ConflictException("The season has not started.");
            if(occurrence.AssignedUserId==userId||occurrence.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED)throw new ConflictException("This chore cannot be taken over.");
            var bounty=await uow.ChoreBounties.GetByOccurrenceIdAsync(occurrence.Id,ct);
            if(occurrence.Status!=ChoreOccurrenceStatus.CRITICAL_OVERDUE && bounty?.Status!=BountyStatus.EXPIRED)throw new ConflictException("Only unresolved overdue or expired-bounty chores can be taken over.");
            if(bounty?.Status==BountyStatus.OPEN)throw new ConflictException("Resolve the open bounty first.");
            if(bounty?.Status==BountyStatus.CLAIMED){
                if(occurrence.Status!=ChoreOccurrenceStatus.CRITICAL_OVERDUE)throw new ConflictException("The claimed bounty has not reached household resolution.");
                bounty.Status=BountyStatus.CANCELLED;uow.ChoreBounties.Update(bounty);
            }
            await penalties.ApplyUntilAsync(occurrence.Id,now,ct);
            var payments=await uow.PaymentObligations.GetByHouseIdAsync(occurrence.Chore.HouseId,ct);
            foreach(var payment in payments.Where(p=>p.OccurrenceId==occurrence.Id&&p.Reason==PaymentObligationReason.FORCED_REASSIGNMENT&&p.Status==PaymentObligationStatus.PENDING)) {
                payment.Status=PaymentObligationStatus.CANCELLED;uow.PaymentObligations.Update(payment);
            }
            await ChoreResponsibilityService.AssignAsync(uow,occurrence,userId,"HOUSEHOLD_RESOLUTION",now.AddHours(24),now,ct);
            uow.ChoreOccurrences.Update(occurrence);
        },ct);
    }
}
