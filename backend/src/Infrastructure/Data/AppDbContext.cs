using Microsoft.EntityFrameworkCore;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<MediaAttachment> MediaAttachments { get; set; } = null!;
    public DbSet<OutboxMessage> OutboxMessages { get; set; } = null!;
    public DbSet<FailedEvent> FailedEvents { get; set; } = null!;
    public DbSet<FailedEventReplay> FailedEventReplays { get; set; } = null!;
    public DbSet<ProcessedMessage> ProcessedMessages { get; set; } = null!;
    public DbSet<User> Users { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;
    public DbSet<House> Houses { get; set; } = null!;
    public DbSet<HouseMember> HouseMembers { get; set; } = null!;
    public DbSet<ChoreSeason> Seasons { get; set; } = null!;
    public DbSet<MemberAvailability> MemberAvailabilities { get; set; } = null!;
    public DbSet<MemberPreference> MemberPreferences { get; set; } = null!;
    public DbSet<MemberConstraint> MemberConstraints { get; set; } = null!;
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
    public DbSet<ChatRoom> ChatRooms { get; set; } = null!;
    public DbSet<ChatMessage> ChatMessages { get; set; } = null!;
    public DbSet<ActionProposal> ActionProposals { get; set; } = null!;
    public DbSet<ProposalConfirmation> ProposalConfirmations { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<FailedEvent>().HasIndex(x => x.Identity).IsUnique();
        modelBuilder.Entity<FailedEvent>().Property(x => x.Identity).HasMaxLength(64);
        modelBuilder.Entity<FailedEvent>().HasIndex(x => new { x.HouseId, x.Status, x.LastFailedAt });
        modelBuilder.Entity<FailedEvent>().HasOne<House>().WithMany().HasForeignKey(x => x.HouseId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<FailedEventReplay>().HasOne<FailedEvent>().WithMany().HasForeignKey(x => x.FailedEventId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<FailedEventReplay>().HasOne<User>().WithMany().HasForeignKey(x => x.RequestedByUserId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<RewardRedemption>().HasIndex(x => new { x.RewardId, x.UserId, x.ClientRequestId }).IsUnique().HasFilter("\"ClientRequestId\" IS NOT NULL");
        modelBuilder.Entity<SeasonRanking>().HasIndex(x => new { x.SeasonId, x.UserId }).IsUnique();
        modelBuilder.Entity<UserAchievement>().HasIndex(x => new { x.UserId, x.AchievementId }).IsUnique();
        modelBuilder.Entity<MediaAttachment>().HasKey(x => x.Id);
        modelBuilder.Entity<MediaAttachment>().HasOne<ChatRoom>().WithMany().HasForeignKey(x => x.RoomId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ChatMessage>().HasOne<MediaAttachment>().WithMany().HasForeignKey(x => x.AttachmentId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ChatMessage>().HasIndex(x => new { x.RoomId, x.SenderId, x.ClientMessageId }).IsUnique().HasFilter("\"ClientMessageId\" IS NOT NULL");
        modelBuilder.Entity<ProcessedMessage>().HasKey(x => new { x.Consumer, x.Id });
        modelBuilder.Entity<OutboxMessage>().HasIndex(x => new { x.PublishedAt, x.CreatedAt });
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
