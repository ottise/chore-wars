using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Application.Services;

public class AchievementCheckService(IUnitOfWork uow, ILogger<AchievementCheckService> logger,
    IHouseMutationCoordinator? mutations = null, TimeProvider? clock = null) : IAchievementCheckService
{
    public Task CheckAchievementsAsync(Guid houseId,Guid userId,AchievementConditionType condition,CancellationToken ct=default)
        => mutations != null ? mutations.RunAsync(houseId,()=>CheckCore(houseId,userId,condition,ct),ct) : CheckCore(houseId,userId,condition,ct);
    private async Task CheckCore(Guid houseId,Guid userId,AchievementConditionType condition,CancellationToken ct)
    {
        var member=await uow.HouseMembers.GetByHouseAndUserIdAsync(houseId,userId,ct);
        if(member?.Status!=HouseMemberStatus.ACTIVE)return;
        var definitions=(await uow.Achievements.GetByHouseIdAsync(houseId,ct)).Where(a=>a.ConditionType==condition).ToList();
        if(definitions.Count==0)return;
        var unlocked=(await uow.UserAchievements.GetByUserIdAsync(userId,ct)).Select(a=>a.AchievementId).ToHashSet();
        int metric;
        if(condition==AchievementConditionType.KARMA_EARNED)
            metric=(await uow.KarmaTransactions.GetByUserIdAsync(userId,ct)).Where(t=>t.HouseId==houseId && t.Amount>0 && t.Type is KarmaTransactionType.CHORE_COMPLETED or KarmaTransactionType.BONUS or KarmaTransactionType.BOUNTY_REWARD).Sum(t=>t.Amount);
        else if(condition==AchievementConditionType.BOUNTIES_CLAIMED)
            metric=await uow.ChoreOccurrences.CountAcceptedBountiesAsync(houseId,userId,ct);
        else {
            var completed=(await uow.ChoreOccurrences.GetByAssignedUserIdAsync(userId,ct))
                .Where(o=>o.Chore.HouseId==houseId && o.Status==ChoreOccurrenceStatus.COMPLETED && (o.CompletedByUserId??o.AssignedUserId)==userId).ToList();
            metric=condition switch {
                AchievementConditionType.CHORES_COMPLETED=>completed.Count,
                AchievementConditionType.STREAK_DAYS=>LongestStreak(completed.Where(o=>o.CompletedAt.HasValue).Select(o=>DateOnly.FromDateTime(ScheduleTime.Local(o.CompletedAt!.Value)))),
                _=>0
            };
        }
        foreach(var item in definitions.Where(a=>a.Threshold>0 && a.Threshold<=metric && !unlocked.Contains(a.Id))) {
            await uow.UserAchievements.AddAsync(new UserAchievement {Id=Guid.NewGuid(),UserId=userId,AchievementId=item.Id,UnlockedAt=(clock??TimeProvider.System).GetUtcNow().UtcDateTime},ct);
            unlocked.Add(item.Id);
            logger.LogInformation("Awarded achievement {AchievementId} to {UserId} in {HouseId}",item.Id,userId,houseId);
        }
        await uow.SaveChangesAsync(ct);
    }
    public static int LongestStreak(IEnumerable<DateOnly> days) {
        DateOnly? previous=null;var current=0;var longest=0;
        foreach(var day in days.Distinct().Order()) {
            current=previous.HasValue && day.DayNumber==previous.Value.DayNumber+1?current+1:1;
            longest=Math.Max(longest,current);previous=day;
        }
        return longest;
    }
}
