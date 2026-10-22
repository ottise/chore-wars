using ChoreWars.Application.DTOs.Season;

namespace ChoreWars.Application.DTOs.AI;

public sealed class ScheduleAvailabilityChange
{
    public Guid UserId { get; set; }
    public DateOnly LocalDate { get; set; }
    public List<AvailabilitySlotRequest> Slots { get; set; } = [];
}
