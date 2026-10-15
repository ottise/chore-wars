using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ProposalConfirmationConfiguration : IEntityTypeConfiguration<ProposalConfirmation>
{
    public void Configure(EntityTypeBuilder<ProposalConfirmation> builder)
    {
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Status).HasConversion<string>().IsRequired();
        builder.Property(x => x.Reason).HasMaxLength(500);
        builder.HasIndex(x => new { x.ProposalId, x.TargetUserId }).IsUnique();
        builder.HasOne(x => x.TargetUser).WithMany().HasForeignKey(x => x.TargetUserId).OnDelete(DeleteBehavior.Restrict);
    }
}
