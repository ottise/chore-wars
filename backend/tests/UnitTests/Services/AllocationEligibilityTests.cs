using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
namespace UnitTests.Services;
public class AllocationEligibilityTests {
    [Fact] public void UndeclaredAvailabilityDoesNotMeanAllDay() {
        Assert.Null(AllocationEligibilityService.FindStart(new ChoreOccurrence { Chore=new Chore() },null,[]));
    }
    [Fact] public void IntervalsMustFitBeforeDeadlineAndAvoidOtherWork() {
        var date=new DateOnly(2026,10,19);
        var occurrence=new ChoreOccurrence{Id=Guid.NewGuid(),Chore=new Chore(),SnapshotMinutes=30,DueDate=ScheduleTime.Utc(date,20*60)};
        var availability=new MemberAvailability{IsAvailable=true,Slots=[new(){StartMinute=18*60,EndMinute=20*60}]};
        var existing=new ChoreOccurrence{Id=Guid.NewGuid(),Chore=new Chore(),SnapshotMinutes=45,PlannedStartAt=ScheduleTime.Utc(date,18*60),DueDate=occurrence.DueDate};
        Assert.Equal(ScheduleTime.Utc(date,18*60+45),AllocationEligibilityService.FindStart(occurrence,availability,[existing]));
        occurrence.SnapshotMinutes=90;
        Assert.Null(AllocationEligibilityService.FindStart(occurrence,availability,[existing]));
    }
}
