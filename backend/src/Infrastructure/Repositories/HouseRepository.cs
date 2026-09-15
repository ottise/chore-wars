using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class HouseRepository : IHouseRepository
{
    private readonly AppDbContext _context;

    public HouseRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<House?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Houses.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<House?> GetByInviteCodeAsync(string inviteCode, CancellationToken cancellationToken = default)
    {
        return await _context.Houses.FirstOrDefaultAsync(h => h.InviteCode == inviteCode, cancellationToken);
    }

    public async Task AddAsync(House house, CancellationToken cancellationToken = default)
    {
        await _context.Houses.AddAsync(house, cancellationToken);
    }

    public void Update(House house)
    {
        _context.Houses.Update(house);
    }

    public void Delete(House house)
    {
        _context.Houses.Remove(house);
    }
}
