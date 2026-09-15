using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class SeasonRankingConfiguration : IEntityTypeConfiguration<SeasonRanking>
{
    public void Configure(EntityTypeBuilder<SeasonRanking> builder)
    {
        builder.HasKey(x => x.Id);

        builder.HasIndex(x => new { x.SeasonId, x.UserId })
            .IsUnique();

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
