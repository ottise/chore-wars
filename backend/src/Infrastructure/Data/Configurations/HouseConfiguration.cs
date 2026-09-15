using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class HouseConfiguration : IEntityTypeConfiguration<House>
{
    public void Configure(EntityTypeBuilder<House> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(x => x.InviteCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.HasIndex(x => x.InviteCode)
            .IsUnique();

        builder.Property(x => x.AvatarUrl)
            .HasMaxLength(500);

        builder.HasMany(x => x.Members)
            .WithOne(x => x.House)
            .HasForeignKey(x => x.HouseId)
            .OnDelete(DeleteBehavior.Cascade);
            
        builder.HasMany(x => x.Seasons)
            .WithOne(x => x.House)
            .HasForeignKey(x => x.HouseId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
