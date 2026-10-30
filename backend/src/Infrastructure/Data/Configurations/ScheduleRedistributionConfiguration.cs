using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;

public sealed class ScheduleRedistributionConfiguration : IEntityTypeConfiguration<ScheduleRedistribution>
{
    public void Configure(EntityTypeBuilder<ScheduleRedistribution> builder)
    {
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.HouseId, x.ActorId, x.ClientRequestId }).IsUnique();
        builder.Property(x => x.ResultJson).HasColumnType("jsonb");
        builder.HasOne<House>().WithMany().HasForeignKey(x => x.HouseId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<ChoreSeason>().WithMany().HasForeignKey(x => x.SeasonId).OnDelete(DeleteBehavior.Restrict);
    }
}
