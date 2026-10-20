using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public partial class ChoreService {
    public async Task<ChoreResponse> ImportRoutineAsync(Guid houseId, Guid seasonId, Guid templateId, Guid userId, CancellationToken ct = default) {
        async Task<ChoreResponse> Import() {
            var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
            if (member?.Status != HouseMemberStatus.ACTIVE) throw new ForbiddenException();
            var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId,ct);
            if (season?.HouseId != houseId) throw new NotFoundException("Season not found.");
            if (season.Status != SeasonStatus.DRAFT) throw new ConflictException("Routines can only be imported into drafts.");
            if (await _unitOfWork.ChoreOccurrences.HasOccurrencesForSeasonAsync(seasonId,ct)) throw new ConflictException("Import routines before generating a schedule.");
            var template = await _unitOfWork.Chores.GetByIdAsync(templateId,ct);
            if (template?.HouseId != houseId || template.SeasonId != null) throw new NotFoundException("Routine not found.");
            var prior = (await _unitOfWork.Chores.GetBySeasonIdAsync(seasonId,ct)).FirstOrDefault(c=>c.SourceTemplateId==templateId);
            if (prior != null) return _mapper.Map<ChoreResponse>(prior);
            var copy = new Chore { Id=Guid.NewGuid(), HouseId=houseId, SeasonId=seasonId, SourceTemplateId=template.Id, Name=template.Name, Description=template.Description, KarmaPoints=template.KarmaPoints, Type=template.Type, Difficulty=template.Difficulty, EstimatedMinutes=template.EstimatedMinutes, FrequencyType=template.FrequencyType, FrequencyValue=template.FrequencyValue, DeadlineMinutes=template.DeadlineMinutes, RecurrenceAnchor=template.RecurrenceAnchor, CustomDates=template.CustomDates.ToList() };
            copy.FrequencyDays=template.FrequencyDays.Select(d=>new ChoreFrequencyDay{Id=Guid.NewGuid(),ChoreId=copy.Id,DayOfWeek=d.DayOfWeek}).ToList();
            season.ScheduleRevision++; _unitOfWork.Seasons.Update(season);
            await _unitOfWork.Chores.AddAsync(copy,ct);await _unitOfWork.SaveChangesAsync(ct);
            return _mapper.Map<ChoreResponse>(copy);
        }
        return _mutations!=null?await _mutations.RunAsync(houseId,Import,ct):await Import();
    }
}
