using System;

namespace ChoreWars.Application.DTOs.Bounty;

public class CreateBountyRequest
{
    public Guid ChoreOccurrenceId { get; set; }
    public decimal Amount { get; set; }
}
