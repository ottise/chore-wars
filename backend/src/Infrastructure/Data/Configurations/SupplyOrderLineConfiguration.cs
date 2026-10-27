using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyOrderLineConfiguration : IEntityTypeConfiguration<SupplyOrderLine> {
 public void Configure(EntityTypeBuilder<SupplyOrderLine> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => new { x.OrderId, x.ProductId }).IsUnique();
b.HasOne<SupplyProduct>().WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Name).HasMaxLength(150); b.Property(x => x.Unit).HasMaxLength(40); b.Property(x => x.UnitPrice).HasPrecision(18,0);
b.ToTable(t => t.HasCheckConstraint("CK_SupplyOrderLine_Quantity", "\"Quantity\" > 0"));
 }
}
