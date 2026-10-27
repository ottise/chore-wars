using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class PaymentWebhookReceiptConfiguration : IEntityTypeConfiguration<PaymentWebhookReceipt> {
 public void Configure(EntityTypeBuilder<PaymentWebhookReceipt> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => x.Reference).IsUnique();
b.Property(x => x.Reference).HasMaxLength(120);
b.HasOne<SupplierPayment>().WithMany().HasForeignKey(x => x.PaymentId).OnDelete(DeleteBehavior.Restrict);
 }
}
