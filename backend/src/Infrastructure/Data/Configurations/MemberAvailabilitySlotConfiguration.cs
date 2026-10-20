using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public class MemberAvailabilitySlotConfiguration : IEntityTypeConfiguration<MemberAvailabilitySlot> {
    public void Configure(EntityTypeBuilder<MemberAvailabilitySlot> builder) {
        builder.HasKey(x => x.Id);
        builder.ToTable(t => t.HasCheckConstraint("CK_AvailabilitySlot_Interval", "\"StartMinute\" >= 0 AND \"EndMinute\" <= 1440 AND \"StartMinute\" < \"EndMinute\""));
        builder.HasOne<MemberAvailability>().WithMany(x => x.Slots).HasForeignKey(x => x.MemberAvailabilityId).OnDelete(DeleteBehavior.Cascade);
    }
}
