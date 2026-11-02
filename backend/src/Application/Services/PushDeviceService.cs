using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public sealed class PushDeviceService(IUnitOfWork unitOfWork, TimeProvider clock) : IPushDeviceService
{
    public async Task RegisterAsync(Guid userId, string token, string platform, CancellationToken cancellationToken = default)
    {
        token = token.Trim();
        platform = platform.Trim().ToUpperInvariant();
        if (token.Length is < 20 or > 4096) throw new DomainException("Invalid push registration token.");
        if (platform is not ("ANDROID" or "IOS")) throw new DomainException("Unsupported push platform.");

        var now = clock.GetUtcNow().UtcDateTime;
        var existing = await unitOfWork.PushDeviceTokens.GetByTokenAsync(token, cancellationToken);
        if (existing == null)
        {
            await unitOfWork.PushDeviceTokens.AddAsync(new PushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = platform,
                CreatedAt = now,
                UpdatedAt = now
            }, cancellationToken);
        }
        else
        {
            existing.UserId = userId;
            existing.Platform = platform;
            existing.UpdatedAt = now;
            unitOfWork.PushDeviceTokens.Update(existing);
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task RevokeAsync(Guid userId, string token, CancellationToken cancellationToken = default)
    {
        token = token.Trim();
        if (token.Length is < 20 or > 4096) return;
        await unitOfWork.PushDeviceTokens.DeleteAsync(userId, token, cancellationToken);
        await unitOfWork.SaveChangesAsync(cancellationToken);
    }
}
