using System;
using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IUnitOfWork : IDisposable
{
    IUserRepository Users { get; }
    IRefreshTokenRepository RefreshTokens { get; }
    IHouseRepository Houses { get; }
    IHouseMemberRepository HouseMembers { get; }
    IChoreSeasonRepository Seasons { get; }
    IMemberAvailabilityRepository MemberAvailabilities { get; }
    ISeasonRankingRepository SeasonRankings { get; }
    IChoreRepository Chores { get; }
    IChoreFrequencyDayRepository ChoreFrequencyDays { get; }
    IChoreOccurrenceRepository ChoreOccurrences { get; }
    IKarmaTransactionRepository KarmaTransactions { get; }
    IRewardRepository Rewards { get; }
    IRewardRedemptionRepository RewardRedemptions { get; }
    IAchievementRepository Achievements { get; }
    IUserAchievementRepository UserAchievements { get; }
    IChoreBountyRepository ChoreBounties { get; }
    IPaymentObligationRepository PaymentObligations { get; }
    INotificationRepository Notifications { get; }

    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
