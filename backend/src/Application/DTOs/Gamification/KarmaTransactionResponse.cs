using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.DTOs.Gamification;

public class KarmaTransactionResponse
{
    public Guid Id { get; set; }
    public int Amount { get; set; }
    public KarmaTransactionType Type { get; set; }
    public string Description { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
