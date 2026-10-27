using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplierPaymentConfiguration : IEntityTypeConfiguration<SupplierPayment> {
 public void Configure(EntityTypeBuilder<SupplierPayment> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => x.OrderCode).IsUnique();
b.HasOne<SupplyOrder>().WithMany().HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Status).HasConversion<string>(); b.Property(x => x.Amount).HasPrecision(18,0);
b.Property(x => x.Reference).HasMaxLength(120); b.Property(x => x.PaymentLinkId).HasMaxLength(120); b.Property(x => x.CheckoutUrl).HasMaxLength(2000);
 }
}
