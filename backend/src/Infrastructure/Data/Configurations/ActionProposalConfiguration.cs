using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ActionProposalConfiguration : IEntityTypeConfiguration<ActionProposal>
{
    public void Configure(EntityTypeBuilder<ActionProposal> builder)
    {
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Type).HasConversion<string>().IsRequired();
        builder.Property(x => x.Status).HasConversion<string>().IsRequired();
        builder.Property(x => x.Title).HasMaxLength(150).IsRequired();
        builder.Property(x => x.Description).HasMaxLength(1000).IsRequired();
        builder.Property(x => x.PayloadJson).HasColumnType("jsonb").IsRequired();
        builder.HasIndex(x => x.HouseId);
        builder.HasIndex(x => x.RoomId);
        builder.HasIndex(x => new { x.RoomId, x.Status });

        builder.HasOne(x => x.House).WithMany().HasForeignKey(x => x.HouseId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.Room).WithMany().HasForeignKey(x => x.RoomId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.Creator).WithMany().HasForeignKey(x => x.CreatorId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(x => x.Confirmations).WithOne(x => x.Proposal).HasForeignKey(x => x.ProposalId).OnDelete(DeleteBehavior.Cascade);
    }
}
