using System;
using System.Threading;
using System.Threading.Tasks;

namespace ChoreWars.Application.Interfaces.Services;

public interface IChoreGenerationService
{
    /// <summary>
    /// Generates ChoreOccurrences for a given season based on Chore Templates and their Frequencies.
    /// Snapshots Karma. Prevents duplicate generation.
    /// </summary>
    Task GenerateOccurrencesAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default);
}
