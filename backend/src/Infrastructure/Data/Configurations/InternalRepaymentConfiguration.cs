using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class InternalRepaymentConfiguration : IEntityTypeConfiguration<InternalRepayment> {
 public void Configure(EntityTypeBuilder<InternalRepayment> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => new { x.ObligationId, x.ClientRequestId }).IsUnique();
b.HasOne<PaymentObligation>().WithMany().HasForeignKey(x => x.ObligationId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Status).HasConversion<string>(); b.Property(x => x.Amount).HasPrecision(18,0);
b.Property(x => x.Reference).HasMaxLength(300); b.Property(x => x.ResponseReason).HasMaxLength(500);
b.ToTable(t => t.HasCheckConstraint("CK_InternalRepayment_Amount", "\"Amount\" > 0"));
 }
}
