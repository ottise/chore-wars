using System;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Auth;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Application.DTOs.User;

namespace ChoreWars.Application.Services;

public class AuthService : IAuthService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IAuthTokenProvider _tokenProvider;
    private readonly IEmailOtpService? _emailOtp;

    public AuthService(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        IPasswordHasher passwordHasher,
        IAuthTokenProvider tokenProvider, IEmailOtpService? emailOtp = null)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _passwordHasher = passwordHasher;
        _tokenProvider = tokenProvider;
        _emailOtp = emailOtp;
    }

    public async Task RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        if (_emailOtp?.Required == true && !_emailOtp.IsConfigured)
            throw new ConflictException("Account email is not available yet. Please try again later or sign in with Google.");
        var existingUser = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
        if (existingUser != null)
        {
            throw new ConflictException("Email is already in use.");
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = request.Email.Trim().ToLowerInvariant(),
            DisplayName = request.DisplayName,
            PasswordHash = _passwordHasher.Hash(request.Password),
            CreatedAt = DateTime.UtcNow,
            EmailVerifiedAt = _emailOtp?.Required == true ? null : DateTime.UtcNow
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Users.AddAsync(user, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
        if (user == null || string.IsNullOrEmpty(user.PasswordHash) || !_passwordHasher.Verify(request.Password, user.PasswordHash))
        {
            throw new ForbiddenException("Invalid credentials.");
        }
        if (_emailOtp?.Required == true && !user.EmailVerifiedAt.HasValue)
            throw new ForbiddenException("Verify your email before signing in. Use Verify email to request a code.");

        var response = _mapper.Map<LoginResponse>(user);
        response.Token = _tokenProvider.GenerateJwtToken(user);
        response.RefreshToken = _tokenProvider.GenerateRefreshToken();

        var refreshTokenEntity = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = response.RefreshToken,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(AuthConstants.RefreshTokenExpirationDays)
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.RefreshTokens.AddAsync(refreshTokenEntity, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return response;
    }

    public async Task<LoginResponse> RefreshTokenAsync(RefreshTokenRequest request, CancellationToken cancellationToken = default)
    {
        var tokenEntity = await _unitOfWork.RefreshTokens.GetByTokenAsync(request.RefreshToken, cancellationToken);
        if (tokenEntity == null || tokenEntity.RevokedAt != null || tokenEntity.ExpiresAt < DateTime.UtcNow)
        {
            throw new ForbiddenException("Invalid or expired refresh token.");
        }

        var user = await _unitOfWork.Users.GetByIdAsync(tokenEntity.UserId, cancellationToken);
        if (user == null)
        {
            throw new NotFoundException(nameof(User), tokenEntity.UserId);
        }

        tokenEntity.RevokedAt = DateTime.UtcNow;
        _unitOfWork.RefreshTokens.Update(tokenEntity);

        var response = _mapper.Map<LoginResponse>(user);
        response.Token = _tokenProvider.GenerateJwtToken(user);
        response.RefreshToken = _tokenProvider.GenerateRefreshToken();

        var newRefreshTokenEntity = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = response.RefreshToken,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(AuthConstants.RefreshTokenExpirationDays)
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.RefreshTokens.AddAsync(newRefreshTokenEntity, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return response;
    }

    public async Task LogoutAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.RefreshTokens.RevokeAllByUserIdAsync(userId, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<UserProfileResponse> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _unitOfWork.Users.GetByIdAsync(userId, cancellationToken);
        if (user == null)
            throw new NotFoundException(nameof(User), userId);

        var profile = _mapper.Map<UserProfileResponse>(user);
        profile.GoogleLinked = user.GoogleSubject != null;
        return profile;
    }

    public async Task<UserProfileResponse> UpdateProfileAsync(Guid userId, UpdateProfileRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _unitOfWork.Users.GetByIdAsync(userId, cancellationToken);
        if (user == null)
            throw new NotFoundException(nameof(User), userId);

        user.DisplayName = request.DisplayName;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Users.Update(user);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<UserProfileResponse>(user);
    }

    public async Task<UserProfileResponse> UpdateAvatarUrlAsync(Guid userId, string avatarUrl, CancellationToken cancellationToken = default)
    {
        var user = await _unitOfWork.Users.GetByIdAsync(userId, cancellationToken);
        if (user == null)
            throw new NotFoundException(nameof(User), userId);

        user.AvatarUrl = avatarUrl;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Users.Update(user);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<UserProfileResponse>(user);
    }
}
