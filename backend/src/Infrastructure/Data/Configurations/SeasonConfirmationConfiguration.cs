using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class SeasonConfirmationConfiguration : IEntityTypeConfiguration<SeasonConfirmation>
{
    public void Configure(EntityTypeBuilder<SeasonConfirmation> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Status)
            .IsRequired()
            .HasConversion<string>();

        builder.Property(x => x.Reason)
            .HasMaxLength(500);

        builder.HasOne(x => x.Season)
            .WithMany(x => x.Confirmations)
            .HasForeignKey(x => x.SeasonId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        // Ensure a user can only have one confirmation per season
        builder.HasIndex(x => new { x.SeasonId, x.UserId })
            .IsUnique();
    }
}
