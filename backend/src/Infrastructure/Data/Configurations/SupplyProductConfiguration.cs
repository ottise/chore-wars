using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyProductConfiguration : IEntityTypeConfiguration<SupplyProduct> {
 public void Configure(EntityTypeBuilder<SupplyProduct> b) {
 b.HasKey(x => x.Id);
 b.Property(x=>x.Version).IsRowVersion();
 b.HasIndex(x => new { x.SupplierId, x.Sku }).IsUnique();
b.HasOne<Supplier>().WithMany().HasForeignKey(x => x.SupplierId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Name).HasMaxLength(150); b.Property(x => x.Sku).HasMaxLength(40); b.Property(x => x.Unit).HasMaxLength(40);
b.Property(x => x.Price).HasPrecision(18,0);
b.ToTable(t => { t.HasCheckConstraint("CK_SupplyProduct_Price", "\"Price\" > 0"); t.HasCheckConstraint("CK_SupplyProduct_Stock", "\"AvailableQuantity\" >= 0"); });
 }
}
