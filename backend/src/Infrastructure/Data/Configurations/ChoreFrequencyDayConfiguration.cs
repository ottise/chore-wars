using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ChoreFrequencyDayConfiguration : IEntityTypeConfiguration<ChoreFrequencyDay>
{
    public void Configure(EntityTypeBuilder<ChoreFrequencyDay> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.DayOfWeek)
            .IsRequired()
            .HasConversion<string>();

        builder.HasOne(x => x.Chore)
            .WithMany(x => x.FrequencyDays)
            .HasForeignKey(x => x.ChoreId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
