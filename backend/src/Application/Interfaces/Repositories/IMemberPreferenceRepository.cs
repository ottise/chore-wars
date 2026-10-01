using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IMemberPreferenceRepository
{
    Task<IEnumerable<MemberPreference>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<MemberPreference?> GetByUserAndChoreIdAsync(Guid userId, Guid choreId, CancellationToken cancellationToken = default);
    Task AddAsync(MemberPreference preference, CancellationToken cancellationToken = default);
    void Delete(MemberPreference preference);
}
