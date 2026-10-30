using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public static class RecurrenceCalculator {
    public static IReadOnlyList<DateOnly> Dates(Chore chore, DateOnly start, DateOnly end) {
        var anchor = chore.RecurrenceAnchor ?? start;
        var days = chore.FrequencyDays.Select(x => x.DayOfWeek).Distinct().ToHashSet();
        var interval = chore.FrequencyValue ?? 1;
        if (chore.FrequencyType is FrequencyType.EVERY_X_DAYS or FrequencyType.EVERY_X_MONTHS or FrequencyType.X_TIMES_PER_WEEK && chore.FrequencyValue is null)
            throw new DomainException("This frequency requires an interval.");
        if (!Enum.IsDefined(chore.FrequencyType) || chore.DeadlineMinutes < 0 || chore.DeadlineMinutes > 1439)
            throw new DomainException("Invalid frequency or deadline.");
        if (chore.FrequencyType is FrequencyType.EVERY_X_DAYS or FrequencyType.EVERY_X_MONTHS && interval <= 0)
            throw new DomainException("Frequency interval must be positive.");
        if (chore.FrequencyType == FrequencyType.X_TIMES_PER_WEEK && (interval < 1 || interval > 7 || days.Count != interval))
            throw new DomainException("Select exactly X distinct weekdays.");
        if (chore.FrequencyType == FrequencyType.SPECIFIC_DAYS && days.Count == 0)
            throw new DomainException("Select at least one weekday.");
        if (days.Any(x => !Enum.IsDefined(x))) throw new DomainException("Invalid weekday.");
        if (chore.FrequencyType == FrequencyType.CUSTOM && chore.CustomDates.Count == 0)
            throw new DomainException("Custom recurrence requires dates.");
        var result = new List<DateOnly>();
        for (var date = start; date <= end; date = date.AddDays(1)) {
            var months = (date.Year - anchor.Year) * 12 + date.Month - anchor.Month;
            bool matches = chore.FrequencyType switch {
                FrequencyType.DAILY => true,
                FrequencyType.EVERY_X_DAYS => date >= anchor && (date.DayNumber - anchor.DayNumber) % interval == 0,
                FrequencyType.WEEKLY => days.Count > 0 ? days.Contains(date.DayOfWeek) : date.DayOfWeek == anchor.DayOfWeek,
                FrequencyType.SPECIFIC_DAYS or FrequencyType.X_TIMES_PER_WEEK => days.Contains(date.DayOfWeek),
                FrequencyType.MONTHLY => months >= 0 && date.Day == Math.Min(anchor.Day, DateTime.DaysInMonth(date.Year, date.Month)),
                FrequencyType.EVERY_X_MONTHS => months >= 0 && months % interval == 0 && date.Day == Math.Min(anchor.Day, DateTime.DaysInMonth(date.Year, date.Month)),
                FrequencyType.YEARLY => date.Year >= anchor.Year && date.Month == anchor.Month && date.Day == Math.Min(anchor.Day, DateTime.DaysInMonth(date.Year, date.Month)),
                FrequencyType.CUSTOM => chore.CustomDates.Contains(date), _ => false
            };
            if (matches && date >= anchor) result.Add(date);
        }
        return result;
    }
}
