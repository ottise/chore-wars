using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class MemberConstraintRepository : IMemberConstraintRepository
{
    private readonly AppDbContext _context;

    public MemberConstraintRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<MemberConstraint?> GetByUserAndHouseIdAsync(Guid userId, Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.MemberConstraints
            .FirstOrDefaultAsync(c => c.UserId == userId && c.HouseId == houseId, cancellationToken);
    }

    public async Task AddAsync(MemberConstraint constraint, CancellationToken cancellationToken = default)
    {
        await _context.MemberConstraints.AddAsync(constraint, cancellationToken);
    }

    public void Update(MemberConstraint constraint)
    {
        _context.MemberConstraints.Update(constraint);
    }
}
