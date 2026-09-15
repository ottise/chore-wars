using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ChoreSeasonConfiguration : IEntityTypeConfiguration<ChoreSeason>
{
    public void Configure(EntityTypeBuilder<ChoreSeason> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(x => x.Status)
            .IsRequired()
            .HasConversion<string>();

        builder.Property(x => x.AllocationMethod)
            .IsRequired()
            .HasConversion<string>();

        builder.HasMany(x => x.Rankings)
            .WithOne(x => x.Season)
            .HasForeignKey(x => x.SeasonId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
