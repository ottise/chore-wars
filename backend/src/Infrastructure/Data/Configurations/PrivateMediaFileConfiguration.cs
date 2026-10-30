using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class PrivateMediaFileConfiguration : IEntityTypeConfiguration<PrivateMediaFile>
{
    public void Configure(EntityTypeBuilder<PrivateMediaFile> builder)
    {
        builder.HasKey(x => x.StorageKey);
        builder.Property(x => x.StorageKey).HasMaxLength(32);
        builder.Property(x => x.Data).IsRequired();
    }
}
