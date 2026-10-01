using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class MemberConstraintConfiguration : IEntityTypeConfiguration<MemberConstraint>
{
    public void Configure(EntityTypeBuilder<MemberConstraint> builder)
    {
        builder.HasKey(x => x.Id);

        builder.HasIndex(x => new { x.HouseId, x.UserId })
            .IsUnique();

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.House)
            .WithMany()
            .HasForeignKey(x => x.HouseId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
