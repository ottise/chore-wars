using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class ObligationAdjustmentConfiguration : IEntityTypeConfiguration<ObligationAdjustment> {
 public void Configure(EntityTypeBuilder<ObligationAdjustment> b) {
 b.HasKey(x => x.Id);
 b.HasOne<PaymentObligation>().WithMany().HasForeignKey(x => x.ObligationId).OnDelete(DeleteBehavior.Restrict);
b.HasOne<SupplyOrder>().WithMany().HasForeignKey(x => x.SourceOrderId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Amount).HasPrecision(18,0); b.Property(x => x.Reason).HasMaxLength(500);
 }
}
