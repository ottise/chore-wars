using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.DTOs.Gamification;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public sealed class RewardService(IUnitOfWork uow, IHouseMutationCoordinator mutations, TimeProvider? clock = null) : IRewardService {
    private TimeProvider Clock => clock ?? TimeProvider.System;
    private async Task<HouseMember> Member(Guid houseId, Guid userId, CancellationToken ct) {
        var member = await uow.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
        if (member?.Status != HouseMemberStatus.ACTIVE) throw new ForbiddenException();
        return member;
    }
    private static CustomRewardResponse Map(Reward r) => new(r.Id,r.Name,r.Description,r.Cost,r.Enabled);
    private static void Validate(string name, string? description, int cost) {
        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length > 100 || cost <= 0 || description?.Length > 1000)
            throw new DomainException("Reward requires a name, positive cost and a description within 1000 characters.");
    }
    public async Task<IReadOnlyList<CustomRewardResponse>> ListAsync(Guid houseId, Guid userId, CancellationToken ct) {
        await Member(houseId,userId,ct);
        return (await uow.Rewards.GetByHouseIdAsync(houseId,ct)).Select(Map).ToList();
    }
    public Task<CustomRewardResponse> CreateAsync(Guid houseId, CreateRewardRequest request, Guid userId, CancellationToken ct) => mutations.RunAsync(houseId,async () => {
        await Member(houseId,userId,ct);
        Validate(request.Name,request.Description,request.Cost);
        var reward = new Reward { Id = Guid.NewGuid(), HouseId = houseId, Name = request.Name.Trim(), Description = request.Description ?? "", Cost = request.Cost, Type = RewardType.CUSTOM, Enabled = true };
        await uow.Rewards.AddAsync(reward,ct); return Map(reward);
    },ct);
    public Task<CustomRewardResponse> UpdateAsync(Guid houseId, Guid rewardId, UpdateRewardRequest request, Guid userId, CancellationToken ct) => mutations.RunAsync(houseId,async () => {
        await Member(houseId,userId,ct);
        Validate(request.Name,request.Description,request.Cost);
        var reward = await uow.Rewards.GetByIdAsync(rewardId,ct) ?? throw new NotFoundException("Reward not found.");
        if (reward.HouseId != houseId || reward.Type != RewardType.CUSTOM) throw new NotFoundException("Custom reward not found.");
        reward.Name = request.Name.Trim(); reward.Description = request.Description ?? "";
        reward.Cost = request.Cost; reward.Enabled = request.Enabled;
        uow.Rewards.Update(reward);
        return Map(reward);
    },ct);
    public Task RedeemAsync(Guid houseId, Guid rewardId, Guid clientRequestId, Guid userId, CancellationToken ct) => mutations.RunAsync(houseId,async () => {
        var member = await Member(houseId,userId,ct);
        if (clientRequestId == Guid.Empty) throw new DomainException("Client request ID is required.");
        var reward = await uow.Rewards.GetByIdAsync(rewardId,ct) ?? throw new NotFoundException("Reward not found.");
        if (reward.HouseId != houseId) throw new NotFoundException("Reward not found.");
        if (await uow.RewardRedemptions.GetByRequestAsync(rewardId,userId,clientRequestId,ct) != null) return;
        if (!reward.Enabled || reward.Type != RewardType.CUSTOM || reward.Cost <= 0) throw new ConflictException("Reward is unavailable.");
        if (member.KarmaBalance < reward.Cost) throw new ConflictException("Insufficient Karma.");
        var now = Clock.GetUtcNow().UtcDateTime;
        var redemption = new RewardRedemption { Id = Guid.NewGuid(), RewardId = rewardId, UserId = userId, ClientRequestId = clientRequestId, CostSnapshot = reward.Cost, Status = RewardRedemptionStatus.USED, RedeemedAt = now, UsedAt = now };
        member.KarmaBalance -= reward.Cost;
        uow.HouseMembers.Update(member);
        await uow.RewardRedemptions.AddAsync(redemption,ct);
        var season = await uow.Seasons.GetActiveSeasonByHouseIdAsync(houseId,ct);
        await uow.KarmaTransactions.AddAsync(new KarmaTransaction { Id = Guid.NewGuid(), HouseId = houseId, SeasonId = season != null && now >= season.StartDate && now <= season.EndDate ? season.Id : null, UserId = userId, Amount = -reward.Cost, Type = KarmaTransactionType.REWARD_REDEEMED, ReferenceId = redemption.Id, CreatedAt = now },ct);
    },ct);
}
