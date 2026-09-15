using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class MemberAvailabilityConfiguration : IEntityTypeConfiguration<MemberAvailability>
{
    public void Configure(EntityTypeBuilder<MemberAvailability> builder)
    {
        builder.HasKey(x => x.Id);

        builder.HasIndex(x => new { x.SeasonId, x.UserId, x.DayOfWeek })
            .IsUnique();

        builder.HasOne(x => x.Season)
            .WithMany()
            .HasForeignKey(x => x.SeasonId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
