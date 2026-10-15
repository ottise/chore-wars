using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class ActionProposal
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid RoomId { get; set; }
    public Guid CreatorId { get; set; }
    public ProposalType Type { get; set; }
    public ProposalStatus Status { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }

    public House House { get; set; } = null!;
    public ChatRoom Room { get; set; } = null!;
    public User Creator { get; set; } = null!;
    public ICollection<ProposalConfirmation> Confirmations { get; set; } = new List<ProposalConfirmation>();
}
