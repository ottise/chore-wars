using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class KarmaTransaction
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid HouseId { get; set; }
    public Guid SeasonId { get; set; }
    public int Amount { get; set; }
    public KarmaTransactionType Type { get; set; }
    public Guid? ReferenceId { get; set; }
    public DateTime CreatedAt { get; set; }

    public User User { get; set; } = null!;
    public House House { get; set; } = null!;
    public ChoreSeason Season { get; set; } = null!;
}
