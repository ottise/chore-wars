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
            var current = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(houseId, ct)
                ?? await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, ct);
            if (current?.Id != seasonId) throw new ConflictException("Open the current season before adding this chore.");
            var template = await _unitOfWork.Chores.GetByIdAsync(templateId,ct);
            if (template?.HouseId != houseId || template.SeasonId != null) throw new NotFoundException("Routine not found.");
            return await CreateChoreCoreAsync(houseId, new CreateChoreRequest {
                SourceTemplateId = template.Id, Name = template.Name, Description = template.Description,
                KarmaPoints = template.KarmaPoints, Type = template.Type, Difficulty = template.Difficulty,
                FrequencyType = template.FrequencyType, FrequencyValue = template.FrequencyValue,
                FrequencyDays = template.FrequencyDays.Select(d => d.DayOfWeek).ToArray(),
                DeadlineMinutes = template.DeadlineMinutes, RecurrenceAnchor = template.RecurrenceAnchor,
                CustomDates = template.CustomDates.ToList()
            }, userId, ct);
        }
        return _mutations!=null?await _mutations.RunAsync(houseId,Import,ct):await Import();
    }
}
