namespace ChoreWars.Domain.Entities;

public sealed class MemberAvailabilityException
{
    public Guid Id { get; set; }
    public Guid SeasonId { get; set; }
    public Guid UserId { get; set; }
    public DateOnly LocalDate { get; set; }
    public string SlotsJson { get; set; } = "[]";
}
