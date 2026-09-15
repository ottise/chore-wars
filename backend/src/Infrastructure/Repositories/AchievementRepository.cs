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

public class AchievementRepository : IAchievementRepository
{
    private readonly AppDbContext _context;

    public AchievementRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Achievement?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Achievements.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<Achievement>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.Achievements
            .Where(a => a.HouseId == houseId)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(Achievement achievement, CancellationToken cancellationToken = default)
    {
        await _context.Achievements.AddAsync(achievement, cancellationToken);
    }

    public void Update(Achievement achievement)
    {
        _context.Achievements.Update(achievement);
    }

    public void Delete(Achievement achievement)
    {
        _context.Achievements.Remove(achievement);
    }
}
