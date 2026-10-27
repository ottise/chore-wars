using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class SupplyReminderDelivery {
public Guid Id { get; set; }
public Guid ScheduleId { get; set; }
public DateTime OccurrenceAt { get; set; }
public DateTime CreatedAt { get; set; }
}
