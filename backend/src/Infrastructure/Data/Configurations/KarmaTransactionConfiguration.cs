using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class KarmaTransactionConfiguration : IEntityTypeConfiguration<KarmaTransaction>
{
    public void Configure(EntityTypeBuilder<KarmaTransaction> builder)
    {
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.ReferenceId, x.Type }).IsUnique().HasFilter("\"ReferenceId\" IS NOT NULL AND \"Type\" IN ('CHORE_COMPLETED','BONUS')");
        builder.HasIndex(x => new { x.ReferenceId, x.PenaltyStep }).IsUnique().HasFilter("\"ReferenceId\" IS NOT NULL AND \"PenaltyStep\" IS NOT NULL AND \"Type\" = 'PENALTY'");

        builder.Property(x => x.Type)
            .IsRequired()
            .HasConversion<string>();

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.House)
            .WithMany()
            .HasForeignKey(x => x.HouseId)
            .OnDelete(DeleteBehavior.Restrict);
            
        builder.HasOne(x => x.Season)
            .WithMany()
            .HasForeignKey(x => x.SeasonId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
