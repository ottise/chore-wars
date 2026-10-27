using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class OrderCostShareConfiguration : IEntityTypeConfiguration<OrderCostShare> {
 public void Configure(EntityTypeBuilder<OrderCostShare> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => new { x.OrderId, x.UserId }).IsUnique();
b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.DisplayName).HasMaxLength(150); b.Property(x => x.Amount).HasPrecision(18,0);
b.ToTable(t => t.HasCheckConstraint("CK_OrderCostShare_Amount", "\"Amount\" >= 0"));
 }
}
