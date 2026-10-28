using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public sealed class HouseCalendarService(IHouseCalendarRepository repository, IHouseAccessService access) : IHouseCalendarService
{
    public const int MaximumRangeDays = 42;
    public async Task<HouseCalendarResponse> ReadAsync(Guid house, Guid actor, DateOnly from, DateOnly to, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house, actor, ct);
        if (to < from || to.DayNumber - from.DayNumber >= MaximumRangeDays || to == DateOnly.MaxValue)
            throw new DomainException("Choose a calendar range of up to 42 days.");
        var rows = await repository.ReadAsync(house, ScheduleTime.Utc(from, 0), ScheduleTime.Utc(to.AddDays(1), 0), ct);
        var days = new List<HouseCalendarDayResponse>();
        for (var date = from; date <= to; date = date.AddDays(1))
        {
            var due = rows.Where(x => Day(x.DueDate) == date).ToList();
            var completed = rows.Where(x => x.Status == "COMPLETED" && x.CompletedAt.HasValue && Day(x.CompletedAt.Value) == date).ToList();
            var evidence = completed.SelectMany(x => x.EvidenceIds).Distinct().ToList();
            days.Add(new(date, due.Count, completed.Count, due.Count(x => x.Status is "OVERDUE" or "CRITICAL_OVERDUE"),
                evidence.Count, evidence.Take(2).ToList(), due.Concat(completed).DistinctBy(x => x.Id).OrderBy(x => x.DueDate).ThenBy(x => x.Id).ToList()));
        }
        return new(from, to, SupplyConstants.TimeZone, days);
    }
    private static DateOnly Day(DateTime value) => DateOnly.FromDateTime(ScheduleTime.Local(value));
}
