using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplierConfiguration : IEntityTypeConfiguration<Supplier> {
 public void Configure(EntityTypeBuilder<Supplier> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => x.OperatorUserId).IsUnique();
b.HasOne<User>().WithMany().HasForeignKey(x => x.OperatorUserId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.Name).HasMaxLength(120); b.Property(x => x.Phone).HasMaxLength(24);
b.Property(x => x.Email).HasMaxLength(254);
b.Property(x => x.DeliveryArea).HasMaxLength(300); b.Property(x => x.DeliveryFee).HasPrecision(18,0);
b.ToTable(t => t.HasCheckConstraint("CK_Supplier_Fee", "\"DeliveryFee\" >= 0"));
 }
}
