using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyScheduleConfiguration : IEntityTypeConfiguration<SupplySchedule> {
 public void Configure(EntityTypeBuilder<SupplySchedule> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => new { x.HouseId, x.ClientRequestId }).IsUnique();
b.HasIndex(x => new { x.Enabled, x.NextDueAt }); b.Property(x => x.Version).IsConcurrencyToken();
b.HasOne<House>().WithMany().HasForeignKey(x => x.HouseId).OnDelete(DeleteBehavior.Restrict);
b.HasOne<User>().WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Items).HasMaxLength(500); b.Property(x => x.TimeZone).HasMaxLength(80);
 }
}
