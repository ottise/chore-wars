using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ChoreConfiguration : IEntityTypeConfiguration<Chore>
{
    public void Configure(EntityTypeBuilder<Chore> builder)
    {
        builder.HasKey(x => x.Id);
        builder.HasOne<Chore>().WithMany().HasForeignKey(x => x.SourceTemplateId).OnDelete(DeleteBehavior.Restrict);

        builder.Property(x => x.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(x => x.Description)
            .HasMaxLength(500);

        builder.Property(x => x.Type)
            .IsRequired()
            .HasConversion<string>();

        builder.Property(x => x.FrequencyType)
            .IsRequired()
            .HasConversion<string>();

        builder.Property(x => x.Difficulty)
            .IsRequired()
            .HasConversion<string>();

        builder.HasOne(x => x.House)
            .WithMany(x => x.Chores)
            .HasForeignKey(x => x.HouseId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Season)
            .WithMany(x => x.Chores)
            .HasForeignKey(x => x.SeasonId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
