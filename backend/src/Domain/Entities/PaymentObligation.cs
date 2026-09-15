using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class PaymentObligation
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid? SeasonId { get; set; }
    public Guid? OccurrenceId { get; set; }
    public Guid DebtorUserId { get; set; }
    public Guid CreditorUserId { get; set; }
    public decimal Amount { get; set; }
    public PaymentObligationReason Reason { get; set; }
    public PaymentObligationStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? PaidAt { get; set; }

    public House House { get; set; } = null!;
    public ChoreSeason? Season { get; set; }
    public ChoreOccurrence? Occurrence { get; set; }
    public User DebtorUser { get; set; } = null!;
    public User CreditorUser { get; set; } = null!;
}
