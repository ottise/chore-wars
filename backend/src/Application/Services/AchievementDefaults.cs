using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
namespace ChoreWars.Application.Services;
public static class AchievementDefaults {
    public static IEnumerable<Achievement> ForHouse(Guid houseId) => [
        new() {Id=Guid.NewGuid(),HouseId=houseId,Name="First chore",Description="Complete your first chore in this household.",ConditionType=AchievementConditionType.CHORES_COMPLETED,Threshold=1},
        new() {Id=Guid.NewGuid(),HouseId=houseId,Name="Karma collector",Description="Earn 100 Karma from chores in this household.",ConditionType=AchievementConditionType.KARMA_EARNED,Threshold=100},
        new() {Id=Guid.NewGuid(),HouseId=houseId,Name="Three-day streak",Description="Complete chores on three consecutive Vietnam calendar days.",ConditionType=AchievementConditionType.STREAK_DAYS,Threshold=3},
        new() {Id=Guid.NewGuid(),HouseId=houseId,Name="Helping hand",Description="Accept your first bounty in this household.",ConditionType=AchievementConditionType.BOUNTIES_CLAIMED,Threshold=1},
    ];
}
