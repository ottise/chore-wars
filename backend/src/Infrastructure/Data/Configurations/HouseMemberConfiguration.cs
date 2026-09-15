using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class HouseMemberConfiguration : IEntityTypeConfiguration<HouseMember>
{
    public void Configure(EntityTypeBuilder<HouseMember> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Role)
            .IsRequired()
            .HasConversion<string>();

        builder.Property(x => x.Status)
            .IsRequired()
            .HasConversion<string>();

        builder.HasIndex(x => new { x.HouseId, x.UserId })
            .IsUnique();
    }
}
