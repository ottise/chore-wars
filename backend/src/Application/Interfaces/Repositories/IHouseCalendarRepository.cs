using ChoreWars.Application.DTOs.House;
namespace ChoreWars.Application.Interfaces.Repositories;
public interface IHouseCalendarRepository
{
    Task<List<HouseCalendarItemResponse>> ReadAsync(Guid house, DateTime fromUtc, DateTime toExclusiveUtc, CancellationToken ct);
}
