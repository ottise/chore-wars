using ChoreWars.Application.DTOs.Season;
namespace ChoreWars.Application.Interfaces.Services;

public interface IMembershipChoreRedistributor
{
    Task<List<RedistributionResult>> RedistributeAsync(Guid houseId, Guid newUserId, CancellationToken ct);
    Task<RedistributionResult> PreviewAsync(Guid houseId, Guid seasonId, Guid targetUserId, Guid actor, CancellationToken ct);
    Task<RedistributionResult> ConfirmAsync(Guid houseId, Guid seasonId, ConfirmRedistributionRequest request, Guid actor, CancellationToken ct);
}
