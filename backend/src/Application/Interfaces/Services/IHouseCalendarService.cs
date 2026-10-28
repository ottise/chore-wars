using ChoreWars.Application.DTOs.House;
namespace ChoreWars.Application.Interfaces.Services;
public interface IHouseCalendarService
{
    Task<HouseCalendarResponse> ReadAsync(Guid house, Guid actor, DateOnly from, DateOnly to, CancellationToken ct);
}
