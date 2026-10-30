using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class AvatarImageConfiguration : IEntityTypeConfiguration<AvatarImage>
{
    public void Configure(EntityTypeBuilder<AvatarImage> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.ContentType).HasMaxLength(40);
        b.Property(x => x.Data).IsRequired();
    }
}
