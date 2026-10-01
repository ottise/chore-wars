using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IMemberConstraintRepository
{
    Task<MemberConstraint?> GetByUserAndHouseIdAsync(Guid userId, Guid houseId, CancellationToken cancellationToken = default);
    Task AddAsync(MemberConstraint constraint, CancellationToken cancellationToken = default);
    void Update(MemberConstraint constraint);
}
