using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
namespace UnitTests.Services;
public class RecurrenceCalculatorTests {
    [Fact] public void MonthlyAnchorClampsWithoutDrifting() {
        var chore = new Chore { FrequencyType = FrequencyType.MONTHLY, RecurrenceAnchor = new DateOnly(2026,1,31) };
        Assert.Equal(new[] {new DateOnly(2026,2,28),new DateOnly(2026,3,31)}, RecurrenceCalculator.Dates(chore,new DateOnly(2026,2,1),new DateOnly(2026,3,31)));
    }
    [Fact] public void LeapDayYearlyClampsToFebruary28() {
        var chore = new Chore { FrequencyType = FrequencyType.YEARLY, RecurrenceAnchor = new DateOnly(2024,2,29) };
        Assert.Equal(new[] {new DateOnly(2025,2,28)}, RecurrenceCalculator.Dates(chore,new DateOnly(2025,1,1),new DateOnly(2025,12,31)));
    }
    [Fact] public void IntervalKeepsItsAnchorAcrossSeasons() {
        var chore = new Chore { FrequencyType = FrequencyType.EVERY_X_DAYS, FrequencyValue = 3, RecurrenceAnchor = new DateOnly(2026,1,1) };
        Assert.Equal(new[] {new DateOnly(2026,1,7),new DateOnly(2026,1,10)}, RecurrenceCalculator.Dates(chore,new DateOnly(2026,1,6),new DateOnly(2026,1,11)));
    }
    [Fact] public void XTimesRequiresDistinctDaysMatchingX() {
        var chore = new Chore { FrequencyType = FrequencyType.X_TIMES_PER_WEEK, FrequencyValue = 2 };
        Assert.Throws<DomainException>(() => RecurrenceCalculator.Dates(chore,new DateOnly(2026,1,1),new DateOnly(2026,1,7)));
    }
    [Fact] public void CustomDatesAreDeduplicatedAndClipped() {
        var chore = new Chore { FrequencyType = FrequencyType.CUSTOM, CustomDates = [new(2026,1,1),new(2026,1,1),new(2026,2,1)] };
        Assert.Single(RecurrenceCalculator.Dates(chore,new DateOnly(2026,1,1),new DateOnly(2026,1,31)));
    }
    [Fact] public void VietnamDeadlineConvertsToUtc() {
        Assert.Equal(new DateTime(2026,1,1,16,59,0,DateTimeKind.Utc),ScheduleTime.Utc(new DateOnly(2026,1,1),1439));
    }
}
