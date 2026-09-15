using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IHouseRepository
{
    Task<House?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<House?> GetByInviteCodeAsync(string inviteCode, CancellationToken cancellationToken = default);
    Task AddAsync(House house, CancellationToken cancellationToken = default);
    void Update(House house);
    void Delete(House house);
}
