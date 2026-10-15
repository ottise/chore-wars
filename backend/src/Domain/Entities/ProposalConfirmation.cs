using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class ProposalConfirmation
{
    public Guid Id { get; set; }
    public Guid ProposalId { get; set; }
    public Guid TargetUserId { get; set; }
    public ConfirmationStatus Status { get; set; }
    public string? Reason { get; set; }
    public DateTime? RespondedAt { get; set; }

    public ActionProposal Proposal { get; set; } = null!;
    public User TargetUser { get; set; } = null!;
}
