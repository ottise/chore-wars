using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class EmailOtpChallengeConfiguration : IEntityTypeConfiguration<EmailOtpChallenge>
{
    public void Configure(EntityTypeBuilder<EmailOtpChallenge> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Purpose).HasMaxLength(32);
        b.Property(x => x.CodeHash).HasMaxLength(255);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.UserId, x.Purpose, x.CreatedAt });
    }
}
