using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Infrastructure.Data.Configurations;

public class ChatRoomConfiguration : IEntityTypeConfiguration<ChatRoom>
{
    public void Configure(EntityTypeBuilder<ChatRoom> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Name).HasMaxLength(100).IsRequired();
        builder.HasIndex(r => r.HouseId);
        builder.HasOne(r => r.House)
               .WithOne(h => h.ChatRoom)
               .HasForeignKey<ChatRoom>(r => r.HouseId)
               .OnDelete(DeleteBehavior.Cascade);
        builder.HasMany(r => r.Messages)
               .WithOne(m => m.Room)
               .HasForeignKey(m => m.RoomId)
               .OnDelete(DeleteBehavior.Cascade);
    }
}
