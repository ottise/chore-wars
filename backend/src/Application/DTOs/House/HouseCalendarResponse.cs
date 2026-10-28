namespace ChoreWars.Application.DTOs.House;
public sealed record HouseCalendarResponse(DateOnly From, DateOnly To, string TimeZone, List<HouseCalendarDayResponse> Days);
