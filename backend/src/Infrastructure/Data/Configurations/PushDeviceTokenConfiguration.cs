using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace ChoreWars.Infrastructure.Data.Configurations;

public sealed class PushDeviceTokenConfiguration : IEntityTypeConfiguration<PushDeviceToken>
{
    public void Configure(EntityTypeBuilder<PushDeviceToken> builder)
    {
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Token).IsRequired().HasMaxLength(4096);
        builder.Property(x => x.Platform).IsRequired().HasMaxLength(16);
        builder.HasIndex(x => x.Token).IsUnique();
        builder.HasIndex(x => x.UserId);
        builder.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
