using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyOrderConfiguration : IEntityTypeConfiguration<SupplyOrder> {
 public void Configure(EntityTypeBuilder<SupplyOrder> b) {
 b.HasKey(x => x.Id);
 b.Property(x => x.Workflow).HasConversion<string>().HasMaxLength(32).HasDefaultValue(ChoreWars.Domain.Enums.SupplyOrderWorkflow.LEGACY_SHARED);
 b.Property(x => x.SupplierEmail).HasMaxLength(320); b.Property(x => x.Note).HasMaxLength(1000);
 b.Property(x => x.PaymentConfirmationSource).HasMaxLength(32); b.Property(x => x.PaymentReference).HasMaxLength(200);
 b.Property(x => x.RecordedPaidAmount).HasPrecision(18, 0);
 b.HasIndex(x => new { x.HouseId, x.CreatorUserId, x.ClientRequestId }).IsUnique();
b.HasIndex(x => new { x.HouseId, x.CreatedAt }); b.Property(x => x.Version).IsConcurrencyToken();
b.HasOne<House>().WithMany().HasForeignKey(x => x.HouseId).OnDelete(DeleteBehavior.Restrict);
b.HasOne<Supplier>().WithMany().HasForeignKey(x => x.SupplierId).OnDelete(DeleteBehavior.Restrict);
b.HasOne<User>().WithMany().HasForeignKey(x => x.PayerUserId).OnDelete(DeleteBehavior.Restrict);
b.HasOne<User>().WithMany().HasForeignKey(x => x.CreatorUserId).OnDelete(DeleteBehavior.Restrict);
b.HasOne<ActionProposal>().WithMany().HasForeignKey(x => x.ProposalId).OnDelete(DeleteBehavior.Restrict);
b.HasMany(x => x.Lines).WithOne().HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
b.HasMany(x => x.Shares).WithOne().HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
b.Property(x => x.Status).HasConversion<string>(); b.Property(x => x.CreatedVia).HasConversion<string>();
b.Property(x => x.Total).HasPrecision(18,0); b.Property(x => x.DeliveryFee).HasPrecision(18,0); b.Property(x => x.RefundedAmount).HasPrecision(18,0);
b.Property(x => x.DeliveryAddress).HasMaxLength(500); b.Property(x => x.ContactPhone).HasMaxLength(24);
b.Property(x => x.SupplierName).HasMaxLength(120); b.Property(x => x.SupplierPhone).HasMaxLength(24);
b.Property(x => x.RequestFingerprint).HasMaxLength(64);
 }
}
