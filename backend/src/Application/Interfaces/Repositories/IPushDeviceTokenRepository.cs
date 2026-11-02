using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IPushDeviceTokenRepository
{
    Task<PushDeviceToken?> GetByTokenAsync(string token, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PushDeviceToken>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(PushDeviceToken token, CancellationToken cancellationToken = default);
    void Update(PushDeviceToken token);
    Task DeleteAsync(Guid userId, string token, CancellationToken cancellationToken = default);
    Task DeleteByTokenAsync(string token, CancellationToken cancellationToken = default);
}
