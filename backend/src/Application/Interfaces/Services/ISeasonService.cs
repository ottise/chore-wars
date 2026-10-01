using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Season;

namespace ChoreWars.Application.Interfaces.Services;

public interface ISeasonService
{
    Task<SeasonResponse?> GetActiveSeasonAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<SeasonResponse> CreateSeasonAsync(Guid houseId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task StartSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task EndSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task SetAvailabilityAsync(Guid seasonId, MemberAvailabilityRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<SeasonRankingResponse>> GetRankingsAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task<SeasonResponse> CloneSeasonAsync(Guid seasonId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task GenerateScheduleAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task ConfirmSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task RejectSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreWars.Application.DTOs.Chore.ChoreOccurrenceResponse>> GetOccurrencesAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
}

