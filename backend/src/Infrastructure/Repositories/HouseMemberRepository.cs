using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class HouseMemberRepository : IHouseMemberRepository
{
    private readonly AppDbContext _context;

    public HouseMemberRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<HouseMember?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.HouseMembers
            .Include(m => m.User)
            .FirstOrDefaultAsync(m => m.Id == id, cancellationToken);
    }

    public async Task<HouseMember?> GetByHouseAndUserIdAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.HouseMembers
            .Include(m => m.User)
            .FirstOrDefaultAsync(m => m.HouseId == houseId && m.UserId == userId, cancellationToken);
    }

    public async Task<IEnumerable<HouseMember>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.HouseMembers
            .Include(m => m.User)
            .Where(m => m.HouseId == houseId)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<HouseMember>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.HouseMembers
            .Include(m => m.User)
            .Where(m => m.UserId == userId)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(HouseMember houseMember, CancellationToken cancellationToken = default)
    {
        await _context.HouseMembers.AddAsync(houseMember, cancellationToken);
    }

    public void Update(HouseMember houseMember)
    {
        _context.HouseMembers.Update(houseMember);
    }

    public void Delete(HouseMember houseMember)
    {
        _context.HouseMembers.Remove(houseMember);
    }
}
