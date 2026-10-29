using System.Security.Cryptography;
using System.Text;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace ChoreWars.Infrastructure.Auth;

public sealed class EmailOtpService(AppDbContext db, IAccountEmailSender sender,
    IPasswordHasher passwords, TimeProvider clock, IConfiguration configuration) : IEmailOtpService
{
    public bool Required => configuration.GetValue("EmailVerification:Required", true);
    public bool IsConfigured => sender.IsConfigured;
    private string Hash(Guid id, string code) => Convert.ToHexString(HMACSHA256.HashData(
        Encoding.UTF8.GetBytes(configuration["Jwt:Secret"] ?? throw new InvalidOperationException("Signing key is missing.")),
        Encoding.UTF8.GetBytes($"{id:N}:{code}")));

    public async Task RequestAsync(string email, string purpose, CancellationToken ct)
    {
        if (purpose is not ("VERIFY_EMAIL" or "RESET_PASSWORD")) throw new DomainException("Choose a valid verification purpose.");
        if (!sender.IsConfigured) throw new ConflictException("Account email is not available yet. Please try again later.");
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({"email-otp:" + email.ToLowerInvariant()}, 0))", ct);
        var user = await db.Users.SingleOrDefaultAsync(u => u.Email.ToLower() == email.ToLower(), ct);
        // Same response for unknown accounts, Google-only password resets and already verified addresses.
        if (user == null || purpose == "VERIFY_EMAIL" && user.EmailVerifiedAt.HasValue ||
            purpose == "RESET_PASSWORD" && (!user.EmailVerifiedAt.HasValue || string.IsNullOrEmpty(user.PasswordHash))) return;
        var now = clock.GetUtcNow().UtcDateTime;
        var prior = await db.EmailOtpChallenges.Where(x => x.UserId == user.Id && x.Purpose == purpose).OrderByDescending(x => x.CreatedAt).ToListAsync(ct);
        if (prior.FirstOrDefault()?.CreatedAt > now.AddSeconds(-60)) return;
        foreach (var old in prior.Where(x => x.ConsumedAt == null)) old.ConsumedAt = now;
        var id = Guid.NewGuid();
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        db.EmailOtpChallenges.Add(new() { Id = id, UserId = user.Id, Purpose = purpose, CodeHash = Hash(id, code),
            CreatedAt = now, ExpiresAt = now.AddMinutes(10) });
        await db.SaveChangesAsync(ct);
        try { await sender.SendCodeAsync(user.Email, code, purpose, ct); }
        catch (Exception e) when (e is not OperationCanceledException) { throw new ConflictException("Could not send your code. Please try again later."); }
        await tx.CommitAsync(ct);
    }

    public async Task VerifyAsync(string email, string code, string? newPassword, CancellationToken ct)
    {
        if (code.Length != 6 || !code.All(char.IsAsciiDigit)) throw new DomainException("Enter the six-digit code from your email.");
        if (newPassword != null && (newPassword.Length < 6 || newPassword.Length > 128)) throw new DomainException("Use a password from 6 to 128 characters.");
        var purpose = newPassword == null ? "VERIFY_EMAIL" : "RESET_PASSWORD";
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({"email-otp:" + email.ToLowerInvariant()}, 0))", ct);
        var user = await db.Users.SingleOrDefaultAsync(u => u.Email.ToLower() == email.ToLower(), ct);
        var now = clock.GetUtcNow().UtcDateTime;
        var challenge = user == null ? null : await db.EmailOtpChallenges.Where(x => x.UserId == user.Id && x.Purpose == purpose && x.ConsumedAt == null)
            .OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        if (challenge == null || challenge.ExpiresAt <= now || challenge.FailedAttempts >= 5)
            throw new ForbiddenException("The code is invalid or expired. Request a new code.");
        if (!CryptographicOperations.FixedTimeEquals(Convert.FromHexString(challenge.CodeHash), Convert.FromHexString(Hash(challenge.Id, code))))
        {
            challenge.FailedAttempts++;
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
            throw new ForbiddenException("The code is invalid or expired. Request a new code.");
        }
        challenge.ConsumedAt = now;
        user!.EmailVerifiedAt ??= now;
        if (newPassword != null)
        {
            user.PasswordHash = passwords.Hash(newPassword);
            await db.RefreshTokens.Where(x => x.UserId == user.Id && x.RevokedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.RevokedAt, now), ct);
        }
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
    }
}
