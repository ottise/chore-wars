using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ChoreBountyConfiguration : IEntityTypeConfiguration<ChoreBounty>
{
    public void Configure(EntityTypeBuilder<ChoreBounty> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Status)
            .IsRequired()
            .HasConversion<string>();

        builder.HasIndex(x => x.ChoreOccurrenceId)
            .IsUnique(); // One active bounty per occurrence usually

        builder.HasOne(x => x.ChoreOccurrence)
            .WithMany()
            .HasForeignKey(x => x.ChoreOccurrenceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.PostedByUser)
            .WithMany()
            .HasForeignKey(x => x.PostedByUserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
