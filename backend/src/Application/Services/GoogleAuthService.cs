using ChoreWars.Application.DTOs.Auth;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using FluentValidation;

namespace ChoreWars.Application.Services;

public sealed class GoogleAuthService(IUnitOfWork unitOfWork, IGoogleIdentityVerifier verifier,
    IAuthTokenProvider tokens, IValidator<GoogleLoginRequest> validator, TimeProvider clock) : IGoogleAuthService
{
    public async Task<LoginResponse> LoginAsync(GoogleLoginRequest request, CancellationToken cancellationToken)
    {
        await validator.ValidateAndThrowAsync(request, cancellationToken);
        var identity = await verifier.VerifyAsync(request.IdToken, cancellationToken);
        await unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await unitOfWork.Users.LockGoogleIdentityAsync(identity.Subject, identity.Email, cancellationToken);
            var user = await unitOfWork.Users.GetByGoogleSubjectAsync(identity.Subject, cancellationToken);
            if (user == null)
            {
                if (await unitOfWork.Users.GetByGoogleEmailAsync(identity.Email, cancellationToken) != null)
                    throw new ConflictException("This email already has an account. Sign in with your password, then choose Link Google in My Account.");
                var displayName = string.IsNullOrWhiteSpace(identity.DisplayName) ? identity.Email.Split('@')[0] : identity.DisplayName.Trim();
                user = new User
                {
                    Id = Guid.NewGuid(), GoogleSubject = identity.Subject, Email = identity.Email.ToLowerInvariant(),
                    DisplayName = displayName[..Math.Min(displayName.Length, 100)],
                    AvatarUrl = identity.AvatarUrl, CreatedAt = clock.GetUtcNow().UtcDateTime
                };
                await unitOfWork.Users.AddAsync(user, cancellationToken);
            }
            user.EmailVerifiedAt ??= clock.GetUtcNow().UtcDateTime;
            var response = new LoginResponse
            {
                UserId = user.Id, DisplayName = user.DisplayName,
                Token = tokens.GenerateJwtToken(user), RefreshToken = tokens.GenerateRefreshToken()
            };
            await unitOfWork.RefreshTokens.AddAsync(new RefreshToken
            {
                Id = Guid.NewGuid(), UserId = user.Id, Token = response.RefreshToken,
                CreatedAt = clock.GetUtcNow().UtcDateTime,
                ExpiresAt = clock.GetUtcNow().UtcDateTime.AddDays(AuthConstants.RefreshTokenExpirationDays)
            }, cancellationToken);
            await unitOfWork.SaveChangesAsync(cancellationToken);
            await unitOfWork.CommitTransactionAsync(cancellationToken);
            return response;
        }
        catch
        {
            await unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task LinkAsync(Guid userId, GoogleLoginRequest request, CancellationToken cancellationToken)
    {
        await validator.ValidateAndThrowAsync(request, cancellationToken);
        var identity = await verifier.VerifyAsync(request.IdToken, cancellationToken);
        await unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await unitOfWork.Users.LockGoogleIdentityAsync(identity.Subject, identity.Email, cancellationToken);
            var user = await unitOfWork.Users.GetByIdAsync(userId, cancellationToken)
                ?? throw new NotFoundException("Account not found.");
            if (!string.Equals(user.Email, identity.Email, StringComparison.OrdinalIgnoreCase))
                throw new ForbiddenException("Choose the Google account with the same email as your Chore Wars account.");
            var linkedUser = await unitOfWork.Users.GetByGoogleSubjectAsync(identity.Subject, cancellationToken);
            if (linkedUser != null && linkedUser.Id != userId || user.GoogleSubject != null && user.GoogleSubject != identity.Subject)
                throw new ConflictException("This account already has a different Google link.");
            user.GoogleSubject = identity.Subject;
            user.EmailVerifiedAt ??= clock.GetUtcNow().UtcDateTime;
            unitOfWork.Users.Update(user);
            await unitOfWork.SaveChangesAsync(cancellationToken);
            await unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }
}
