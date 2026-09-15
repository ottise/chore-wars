using Microsoft.EntityFrameworkCore;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;
    public DbSet<House> Houses { get; set; } = null!;
    public DbSet<HouseMember> HouseMembers { get; set; } = null!;
    public DbSet<ChoreSeason> Seasons { get; set; } = null!;
    public DbSet<MemberAvailability> MemberAvailabilities { get; set; } = null!;
    public DbSet<SeasonRanking> SeasonRankings { get; set; } = null!;
    public DbSet<Chore> Chores { get; set; } = null!;
    public DbSet<ChoreFrequencyDay> ChoreFrequencyDays { get; set; } = null!;
    public DbSet<ChoreOccurrence> ChoreOccurrences { get; set; } = null!;
    public DbSet<SeasonConfirmation> SeasonConfirmations { get; set; } = null!;
    public DbSet<KarmaTransaction> KarmaTransactions { get; set; } = null!;
    public DbSet<Reward> Rewards { get; set; } = null!;
    public DbSet<RewardRedemption> RewardRedemptions { get; set; } = null!;
    public DbSet<Achievement> Achievements { get; set; } = null!;
    public DbSet<UserAchievement> UserAchievements { get; set; } = null!;
    public DbSet<ChoreBounty> ChoreBounties { get; set; } = null!;
    public DbSet<PaymentObligation> PaymentObligations { get; set; } = null!;
    public DbSet<Notification> Notifications { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
