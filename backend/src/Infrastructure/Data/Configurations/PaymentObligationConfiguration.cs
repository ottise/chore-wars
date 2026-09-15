using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class PaymentObligationConfiguration : IEntityTypeConfiguration<PaymentObligation>
{
    public void Configure(EntityTypeBuilder<PaymentObligation> builder)
    {
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Reason)
            .IsRequired()
            .HasConversion<string>();

        builder.Property(x => x.Status)
            .IsRequired()
            .HasConversion<string>();

        builder.HasOne(x => x.House)
            .WithMany()
            .HasForeignKey(x => x.HouseId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.DebtorUser)
            .WithMany()
            .HasForeignKey(x => x.DebtorUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.CreditorUser)
            .WithMany()
            .HasForeignKey(x => x.CreditorUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Season)
            .WithMany()
            .HasForeignKey(x => x.SeasonId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(x => x.Occurrence)
            .WithMany()
            .HasForeignKey(x => x.OccurrenceId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
