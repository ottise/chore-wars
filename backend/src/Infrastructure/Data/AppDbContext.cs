using Microsoft.EntityFrameworkCore;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.AI;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Data;

public class AppDbContext : DbContext
{
    private readonly bool _aiEnabled;
    private readonly TimeProvider _clock;
    public AppDbContext(DbContextOptions<AppDbContext> options, IOptions<AIOptions>? aiOptions = null, TimeProvider? clock = null) : base(options)
    {
        _aiEnabled = aiOptions?.Value.Enabled == true;
        _clock = clock ?? TimeProvider.System;
    }

    public DbSet<AIResponsibilityContextSnapshot> AIResponsibilityContextSnapshots { get; set; } = null!;
    public DbSet<AIObservation> AIObservations { get; set; } = null!;
    public DbSet<AIRecommendation> AIRecommendations { get; set; } = null!;
    public DbSet<HouseAiSettings> HouseAiSettings { get; set; } = null!;
    public DbSet<MemberAiConsent> MemberAiConsents { get; set; } = null!;
    public DbSet<MemberAvailabilityException> MemberAvailabilityExceptions { get; set; } = null!;
    public DbSet<ChoreEvidence> ChoreEvidence { get; set; } = null!;
    public DbSet<AIChatInsight> AIChatInsights { get; set; } = null!;

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        if (_aiEnabled) await AITelemetryCapture.CaptureAsync(this, _clock.GetUtcNow().UtcDateTime, cancellationToken);
        return await base.SaveChangesAsync(cancellationToken);
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
        modelBuilder.Entity<AIObservation>().HasIndex(x=>new{x.HouseId,x.UserId,x.ClientRequestId}).IsUnique();
        modelBuilder.Entity<AIObservation>().Property(x=>x.Kind).HasMaxLength(32);
        modelBuilder.Entity<AIObservation>().HasOne<House>().WithMany().HasForeignKey(x=>x.HouseId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<AIObservation>().HasOne<User>().WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Restrict);
        // Draft regeneration replaces occurrences; observations retain the original audit ID without blocking that operation.
        modelBuilder.Entity<AIObservation>().HasIndex(x=>x.OccurrenceId);
        modelBuilder.Entity<House>().Property(x=>x.AiDataSource).HasMaxLength(24).HasDefaultValue("REAL");
        modelBuilder.Entity<House>().ToTable(t=>t.HasCheckConstraint("CK_House_AiDataSource","\"AiDataSource\" IN ('REAL','DEMO_SYNTHETIC')"));
        modelBuilder.Entity<HouseAiSettings>().HasKey(x=>x.HouseId);
        modelBuilder.Entity<AIChatInsight>().HasIndex(x=>x.MessageId).IsUnique();
        modelBuilder.Entity<AIChatInsight>().HasIndex(x=>new{x.Status,x.CreatedAt});
        modelBuilder.Entity<AIChatInsight>().Property(x=>x.ResultJson).HasColumnType("jsonb");
        modelBuilder.Entity<AIChatInsight>().HasOne<ChatMessage>().WithMany().HasForeignKey(x=>x.MessageId).OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<AIChatInsight>().HasOne<House>().WithMany().HasForeignKey(x=>x.HouseId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ChoreEvidence>().HasIndex(x=>new{x.OccurrenceId,x.UploadedByUserId,x.ClientRequestId}).IsUnique();
        modelBuilder.Entity<ChoreEvidence>().HasOne<ChoreOccurrence>().WithMany().HasForeignKey(x=>x.OccurrenceId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ChoreEvidence>().Property(x=>x.VisionJson).HasColumnType("jsonb");
        modelBuilder.Entity<ChoreOccurrence>().HasOne<ChoreEvidence>().WithMany().HasForeignKey(x=>x.EvidenceId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<MemberAiConsent>().HasKey(x=>new{x.HouseId,x.UserId});
        modelBuilder.Entity<MemberAvailabilityException>().HasIndex(x=>new{x.SeasonId,x.UserId,x.LocalDate}).IsUnique();
        modelBuilder.Entity<MemberAvailabilityException>().Property(x=>x.SlotsJson).HasColumnType("jsonb");
        modelBuilder.Entity<AIResponsibilityContextSnapshot>().HasIndex(x=>x.EpisodeId).IsUnique();
        modelBuilder.Entity<AIResponsibilityContextSnapshot>().Property(x=>x.PayloadJson).HasColumnType("jsonb");
        modelBuilder.Entity<AIResponsibilityContextSnapshot>().HasOne<House>().WithMany().HasForeignKey(x=>x.HouseId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<AIRecommendation>().HasIndex(x=>new{x.HouseId,x.ActorId,x.ClientRequestId}).IsUnique();
        modelBuilder.Entity<AIRecommendation>().Property(x=>x.PayloadJson).HasColumnType("jsonb");
        modelBuilder.Entity<AIRecommendation>().Property(x=>x.AvailabilityChangesJson).HasColumnType("jsonb").HasDefaultValue("[]");
        modelBuilder.Entity<AIRecommendation>().HasOne<House>().WithMany().HasForeignKey(x=>x.HouseId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<HouseAiSettings>().HasOne<House>().WithMany().HasForeignKey(x=>x.HouseId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<MemberAiConsent>().HasOne<House>().WithMany().HasForeignKey(x=>x.HouseId).OnDelete(DeleteBehavior.Restrict);
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
