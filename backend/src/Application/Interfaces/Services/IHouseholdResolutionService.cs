namespace ChoreWars.Application.Interfaces.Services;
public interface IHouseholdResolutionService { Task<IReadOnlyList<ChoreWars.Application.DTOs.Chore.ChoreOccurrenceResponse>> ListAsync(Guid houseId, Guid userId, CancellationToken ct); Task TakeResponsibilityAsync(Guid occurrenceId, Guid userId, CancellationToken ct); }
