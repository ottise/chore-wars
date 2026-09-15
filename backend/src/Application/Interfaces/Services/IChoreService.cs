using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Chore;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChoreService
{
    Task<ChoreResponse> CreateChoreAsync(Guid houseId, CreateChoreRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task<ChoreResponse> UpdateChoreAsync(Guid choreId, UpdateChoreRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task DeleteChoreAsync(Guid choreId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreResponse>> GetChoresByHouseAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task AssignChoreAsync(Guid choreId, AssignChoreRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task CompleteChoreAsync(Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default);
    Task SkipChoreAsync(Guid occurrenceId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<ChoreOccurrenceResponse>> GetMyChoresAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
}
