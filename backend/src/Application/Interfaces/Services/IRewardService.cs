using ChoreWars.Application.DTOs.Gamification;
namespace ChoreWars.Application.Interfaces.Services;
public interface IRewardService {
    Task<IReadOnlyList<CustomRewardResponse>> ListAsync(Guid houseId, Guid userId, CancellationToken ct);
    Task<CustomRewardResponse> CreateAsync(Guid houseId, CreateRewardRequest request, Guid userId, CancellationToken ct);
    Task<CustomRewardResponse> UpdateAsync(Guid houseId, Guid rewardId, UpdateRewardRequest request, Guid userId, CancellationToken ct);
    Task RedeemAsync(Guid houseId, Guid rewardId, Guid clientRequestId, Guid userId, CancellationToken ct);
}
