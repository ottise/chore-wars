using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class SupplyDisputeConfiguration:IEntityTypeConfiguration<SupplyDispute>{public void Configure(EntityTypeBuilder<SupplyDispute>b){
 b.HasKey(x=>x.Id);b.HasIndex(x=>new{x.OrderId,x.CreatorUserId,x.ClientRequestId}).IsUnique();
 b.HasOne<SupplyOrder>().WithMany().HasForeignKey(x=>x.OrderId).OnDelete(DeleteBehavior.Restrict);
 b.HasOne<User>().WithMany().HasForeignKey(x=>x.CreatorUserId).OnDelete(DeleteBehavior.Restrict);
 b.HasOne<SupplyProduct>().WithMany().HasForeignKey(x=>x.ProductId).OnDelete(DeleteBehavior.Restrict);
 b.Property(x=>x.Reason).HasMaxLength(500);b.Property(x=>x.Resolution).HasMaxLength(500);
}}
