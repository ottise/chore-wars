using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyOrderActivityConfiguration : IEntityTypeConfiguration<SupplyOrderActivity>
{
    public void Configure(EntityTypeBuilder<SupplyOrderActivity> b)
    {
        b.HasKey(x => x.Id); b.HasIndex(x => new { x.OrderId, x.RecordedAt });
        b.Property(x => x.Kind).HasMaxLength(32); b.Property(x => x.Reference).HasMaxLength(200); b.Property(x => x.Amount).HasPrecision(18, 0);
        b.HasOne<SupplyOrder>().WithMany(x => x.Activities).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
    }
}
