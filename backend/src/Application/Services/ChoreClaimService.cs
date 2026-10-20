using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public partial class ChoreService {
    public async Task ClaimBonusAsync(Guid occurrenceId, Guid userId, CancellationToken ct = default) {
        var context=await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId,ct)??throw new NotFoundException("Occurrence not found.");
        async Task Claim() {
            var occurrence=await _unitOfWork.ChoreOccurrences.GetByIdAsync(occurrenceId,ct)??throw new NotFoundException("Occurrence not found.");
            var member=await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(occurrence.Chore.HouseId,userId,ct);
            if(member?.Status!=HouseMemberStatus.ACTIVE)throw new ForbiddenException();
            var season=await _unitOfWork.Seasons.GetByIdAsync(occurrence.SeasonId,ct);
            var now=_clock.GetUtcNow().UtcDateTime;
            if(season?.Status!=SeasonStatus.ACTIVE||now<season.StartDate||now>season.EndDate||occurrence.DueDate<=now)throw new ConflictException("This bonus chore is not currently available.");
            if(occurrence.Chore.Type!=ChoreType.BONUS||occurrence.Status!=ChoreOccurrenceStatus.ASSIGNED)throw new ConflictException("Only pending bonus chores can be claimed.");
            if(occurrence.AssignedUserId==userId)return;
            if(occurrence.AssignedUserId!=null)throw new ConflictException("Another member has claimed this bonus chore.");
            occurrence.AssignedUserId=userId;
            var episode=new ChoreResponsibility{Id=Guid.NewGuid(),OccurrenceId=occurrence.Id,UserId=userId,Reason="BONUS_CLAIM",StartedAt=now,Deadline=occurrence.DueDate};
            occurrence.Responsibilities.Add(episode);
            await _unitOfWork.ChoreOccurrences.AddResponsibilityAsync(episode,ct);
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            await _unitOfWork.SaveChangesAsync(ct);
        }
        if(_mutations!=null)await _mutations.RunAsync(context.Chore.HouseId,Claim,ct);else await Claim();
    }
}
