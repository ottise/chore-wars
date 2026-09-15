using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Season;

namespace ChoreWars.Application.Interfaces.Services;

public interface ISeasonService
{
    Task<SeasonResponse> CreateSeasonAsync(Guid houseId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task StartSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task EndSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task SetAvailabilityAsync(Guid seasonId, MemberAvailabilityRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<SeasonRankingResponse>> GetRankingsAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task<SeasonResponse> CloneSeasonAsync(Guid seasonId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default);
}
