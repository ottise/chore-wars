using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.Interfaces.Services;

public interface IAchievementCheckService
{
    Task CheckAchievementsAsync(Guid houseId, Guid userId, AchievementConditionType conditionType, CancellationToken cancellationToken = default);
}
