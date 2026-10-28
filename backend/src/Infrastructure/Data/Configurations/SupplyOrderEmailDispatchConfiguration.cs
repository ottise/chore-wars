using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyOrderEmailDispatchConfiguration : IEntityTypeConfiguration<SupplyOrderEmailDispatch>
{
    public void Configure(EntityTypeBuilder<SupplyOrderEmailDispatch> b)
    {
        b.HasKey(x => x.Id); b.HasIndex(x => x.OrderId).IsUnique(); b.HasIndex(x => new { x.State, x.CreatedAt });
        b.Property(x => x.Recipient).HasMaxLength(320); b.Property(x => x.Subject).HasMaxLength(200);
        b.Property(x => x.State).HasMaxLength(32); b.Property(x => x.ErrorCode).HasMaxLength(80);
        b.Property(x => x.LeaseId).IsConcurrencyToken();
        b.HasOne<SupplyOrder>().WithOne(x => x.EmailDispatch).HasForeignKey<SupplyOrderEmailDispatch>(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
    }
}
