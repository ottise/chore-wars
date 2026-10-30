using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace ChoreWars.Infrastructure.Data.Configurations;

public sealed class CloudinaryFileConfiguration : IEntityTypeConfiguration<CloudinaryFile>
{
    public void Configure(EntityTypeBuilder<CloudinaryFile> builder)
    {
        builder.HasKey(x => x.StorageKey);
        builder.Property(x => x.StorageKey).HasMaxLength(64);
        builder.Property(x => x.CloudName).HasMaxLength(128);
        builder.Property(x => x.AssetId).HasMaxLength(128);
        builder.Property(x => x.PublicId).HasMaxLength(256);
        builder.Property(x => x.ResourceType).HasMaxLength(16);
    }
}
