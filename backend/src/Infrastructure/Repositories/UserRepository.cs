using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly AppDbContext _context;

    public UserRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Users.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        return await _context.Users.FirstOrDefaultAsync(u => u.Email == email, cancellationToken);
    }

    public async Task AddAsync(User user, CancellationToken cancellationToken = default)
    {
        await _context.Users.AddAsync(user, cancellationToken);
    }

    public Task<User?> GetByGoogleSubjectAsync(string subject, CancellationToken cancellationToken = default) =>
        _context.Users.FirstOrDefaultAsync(u => u.GoogleSubject == subject, cancellationToken);

    public Task<User?> GetByGoogleEmailAsync(string email, CancellationToken cancellationToken = default) =>
        _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email.ToLower(), cancellationToken);

    public async Task LockGoogleIdentityAsync(string subject, string email, CancellationToken cancellationToken = default)
    {
        // Both keys are locked in a stable order inside the caller's transaction.
        foreach (var key in new[] { "google-sub:" + subject, "google-email:" + email.ToLowerInvariant() }.Order(StringComparer.Ordinal))
            await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({key}, 0))", cancellationToken);
    }

    public void Update(User user)
    {
        _context.Users.Update(user);
    }
}
