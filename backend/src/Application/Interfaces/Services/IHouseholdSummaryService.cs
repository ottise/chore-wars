using ChoreWars.Application.DTOs.House;
namespace ChoreWars.Application.Interfaces.Services;
public interface IHouseholdSummaryService
{
    Task<HouseholdSummaryResponse> ReadAsync(Guid house, Guid actor, DateOnly from, DateOnly to, Guid? season, CancellationToken ct);
}
