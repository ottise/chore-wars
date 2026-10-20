namespace ChoreWars.Domain.Entities;
public class MemberAvailabilitySlot {
    public Guid Id { get; set; }
    public Guid MemberAvailabilityId { get; set; }
    public int StartMinute { get; set; }
    public int EndMinute { get; set; }
}
