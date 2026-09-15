using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ChoreOccurrenceConfiguration : IEntityTypeConfiguration<ChoreOccurrence>
{
    public void Configure(EntityTypeBuilder<ChoreOccurrence> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Status)
            .IsRequired()
            .HasConversion<string>();

        builder.HasOne(x => x.Chore)
            .WithMany(x => x.Occurrences)
            .HasForeignKey(x => x.ChoreId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.AssignedUser)
            .WithMany()
            .HasForeignKey(x => x.AssignedUserId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
