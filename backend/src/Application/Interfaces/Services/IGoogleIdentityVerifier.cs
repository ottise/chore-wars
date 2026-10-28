using ChoreWars.Application.DTOs.Auth;

namespace ChoreWars.Application.Interfaces.Services;

public interface IGoogleIdentityVerifier
{
    Task<GoogleIdentity> VerifyAsync(string idToken, CancellationToken cancellationToken);
}
