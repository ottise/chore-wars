using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IHouseMemberRepository
{
    Task<HouseMember?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<HouseMember?> GetByHouseAndUserIdAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<HouseMember>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<IEnumerable<HouseMember>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(HouseMember houseMember, CancellationToken cancellationToken = default);
    void Update(HouseMember houseMember);
    void Delete(HouseMember houseMember);
}
