using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class SupplySchedule {
public Guid Id { get; set; }
public Guid HouseId { get; set; }
public Guid CreatedByUserId { get; set; }
public Guid ClientRequestId { get; set; }
public string Items { get; set; } = "";
public int DayOfMonth { get; set; }
public int Hour { get; set; }
public int Minute { get; set; }
public string TimeZone { get; set; } = "Asia/Ho_Chi_Minh";
public bool Enabled { get; set; } = true;
public int QuietFromHour { get; set; } = 22;
public int QuietToHour { get; set; } = 8;
public DateTime NextDueAt { get; set; }
public DateTime? SnoozedUntil { get; set; }
public int Version { get; set; } = 1;
}
