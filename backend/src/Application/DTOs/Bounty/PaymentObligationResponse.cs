using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Bounty;

public class PaymentObligationResponse
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid? OccurrenceId { get; set; }
    public Guid DebtorUserId { get; set; }
    public string DebtorDisplayName { get; set; } = string.Empty;
    public Guid CreditorUserId { get; set; }
    public string CreditorDisplayName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public PaymentObligationReason Reason { get; set; }
    public PaymentObligationStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? PaidAt { get; set; }
}