using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore.Storage;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _context;
    private IDbContextTransaction? _transaction;

    public IUserRepository Users { get; }
    public IRefreshTokenRepository RefreshTokens { get; }
    public IHouseRepository Houses { get; }
    public IHouseMemberRepository HouseMembers { get; }
    public IChoreSeasonRepository Seasons { get; }
    public IMemberAvailabilityRepository MemberAvailabilities { get; }
    public ISeasonRankingRepository SeasonRankings { get; }
    public IChoreRepository Chores { get; }
    public IChoreFrequencyDayRepository ChoreFrequencyDays { get; }
    public IChoreOccurrenceRepository ChoreOccurrences { get; }
    public IKarmaTransactionRepository KarmaTransactions { get; }
    public IRewardRepository Rewards { get; }
    public IRewardRedemptionRepository RewardRedemptions { get; }
    public IAchievementRepository Achievements { get; }
    public IUserAchievementRepository UserAchievements { get; }
    public ISeasonConfirmationRepository SeasonConfirmations { get; }
    public IChoreBountyRepository ChoreBounties { get; }
    public IPaymentObligationRepository PaymentObligations { get; }
    public INotificationRepository Notifications { get; }

    public UnitOfWork(
        AppDbContext context,
        IUserRepository users,
        IRefreshTokenRepository refreshTokens,
        IHouseRepository houses,
        IHouseMemberRepository houseMembers,
        IChoreSeasonRepository seasons,
        IMemberAvailabilityRepository memberAvailabilities,
        ISeasonRankingRepository seasonRankings,
        IChoreRepository chores,
        IChoreFrequencyDayRepository choreFrequencyDays,
        IChoreOccurrenceRepository choreOccurrences,
        IKarmaTransactionRepository karmaTransactions,
        IRewardRepository rewards,
        IRewardRedemptionRepository rewardRedemptions,
        IAchievementRepository achievements,
        IUserAchievementRepository userAchievements,
        ISeasonConfirmationRepository seasonConfirmations,
        IChoreBountyRepository choreBounties,
        IPaymentObligationRepository paymentObligations,
        INotificationRepository notifications)
    {
        _context = context;
        Users = users;
        RefreshTokens = refreshTokens;
        Houses = houses;
        HouseMembers = houseMembers;
        Seasons = seasons;
        MemberAvailabilities = memberAvailabilities;
        SeasonRankings = seasonRankings;
        Chores = chores;
        ChoreFrequencyDays = choreFrequencyDays;
        ChoreOccurrences = choreOccurrences;
        KarmaTransactions = karmaTransactions;
        Rewards = rewards;
        RewardRedemptions = rewardRedemptions;
        Achievements = achievements;
        UserAchievements = userAchievements;
        SeasonConfirmations = seasonConfirmations;
        ChoreBounties = choreBounties;
        PaymentObligations = paymentObligations;
        Notifications = notifications;
    }

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default)
    {
        _transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
    }

    public async Task CommitTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    public void Dispose()
    {
        _transaction?.Dispose();
        _context.Dispose();
    }
}
