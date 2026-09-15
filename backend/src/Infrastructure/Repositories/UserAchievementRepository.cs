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

public class UserAchievementRepository : IUserAchievementRepository
{
    private readonly AppDbContext _context;

    public UserAchievementRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<UserAchievement?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.UserAchievements.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<UserAchievement>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.UserAchievements
            .Include(ua => ua.Achievement)
            .Where(ua => ua.UserId == userId)
            .OrderByDescending(ua => ua.UnlockedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(UserAchievement userAchievement, CancellationToken cancellationToken = default)
    {
        await _context.UserAchievements.AddAsync(userAchievement, cancellationToken);
    }
}
