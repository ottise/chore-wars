using ChoreWars.Application.DTOs.Auth;

namespace ChoreWars.Application.Interfaces.Services;

public interface IGoogleAuthService
{
    Task<LoginResponse> LoginAsync(GoogleLoginRequest request, CancellationToken cancellationToken);
    Task LinkAsync(Guid userId, GoogleLoginRequest request, CancellationToken cancellationToken);
}
