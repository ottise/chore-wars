using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplierRefundConfiguration : IEntityTypeConfiguration<SupplierRefund>
{
 public void Configure(EntityTypeBuilder<SupplierRefund> b){
  b.HasKey(x=>x.Id);b.HasIndex(x=>new{x.OrderId,x.ClientRequestId}).IsUnique();
  b.HasOne<SupplyOrder>().WithMany().HasForeignKey(x=>x.OrderId).OnDelete(DeleteBehavior.Restrict);
  b.Property(x=>x.Amount).HasPrecision(18,0);b.Property(x=>x.Reference).HasMaxLength(300);b.Property(x=>x.Reason).HasMaxLength(500);
  b.ToTable(t=>t.HasCheckConstraint("CK_SupplierRefund_Amount","\"Amount\" > 0"));
 }
}
