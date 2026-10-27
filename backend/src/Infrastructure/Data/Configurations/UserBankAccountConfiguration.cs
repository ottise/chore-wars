using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace ChoreWars.Infrastructure.Data.Configurations;
public sealed class UserBankAccountConfiguration : IEntityTypeConfiguration<UserBankAccount> {
 public void Configure(EntityTypeBuilder<UserBankAccount> b) {
 b.HasKey(x => x.Id);
 b.HasIndex(x => x.UserId).IsUnique(); b.Property(x => x.Version).IsConcurrencyToken();
b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
b.Property(x => x.BankName).HasMaxLength(100); b.Property(x => x.AccountName).HasMaxLength(150); b.Property(x => x.AccountNumber).HasMaxLength(40);
 }
}
