using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class MemberPreferenceConfiguration : IEntityTypeConfiguration<MemberPreference>
{
    public void Configure(EntityTypeBuilder<MemberPreference> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Type)
            .IsRequired()
            .HasConversion<string>();

        builder.HasIndex(x => new { x.UserId, x.ChoreId })
            .IsUnique();

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Chore)
            .WithMany()
            .HasForeignKey(x => x.ChoreId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
