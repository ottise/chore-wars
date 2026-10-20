using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;
namespace ChoreWars.Infrastructure.Data.Configurations;
public class ChoreResponsibilityConfiguration : IEntityTypeConfiguration<ChoreResponsibility> {
    public void Configure(EntityTypeBuilder<ChoreResponsibility> b) {
        b.HasKey(x => x.Id);
        b.HasOne<ChoreOccurrence>().WithMany(x => x.Responsibilities).HasForeignKey(x => x.OccurrenceId).OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => x.OccurrenceId).IsUnique().HasFilter("\"EndedAt\" IS NULL");
    }
}
