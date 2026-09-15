using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class PaymentObligation
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid FromUserId { get; set; }
    public Guid ToUserId { get; set; }
    public decimal Amount { get; set; }
    public PaymentObligationReason Reason { get; set; }
    public PaymentObligationStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }

    public House House { get; set; } = null!;
    public User FromUser { get; set; } = null!;
    public User ToUser { get; set; } = null!;
}
