using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyReminderDeliveryConfiguration : IEntityTypeConfiguration<SupplyReminderDelivery> {
 public void Configure(EntityTypeBuilder<SupplyReminderDelivery> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => new { x.ScheduleId, x.OccurrenceAt }).IsUnique();
b.HasOne<SupplySchedule>().WithMany().HasForeignKey(x => x.ScheduleId).OnDelete(DeleteBehavior.Restrict);
 }
}
