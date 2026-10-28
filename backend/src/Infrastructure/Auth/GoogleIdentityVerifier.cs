using ChoreWars.Application.DTOs.Auth;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Google.Apis.Auth;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.Auth;

public sealed class GoogleIdentityVerifier(IOptions<GoogleAuthOptions> options) : IGoogleIdentityVerifier
{
    public async Task<GoogleIdentity> VerifyAsync(string idToken, CancellationToken cancellationToken)
    {
        var settings = options.Value;
        var audiences = settings.ClientIds.Where(x => !string.IsNullOrWhiteSpace(x)).ToArray();
        if (!settings.Enabled || audiences.Length == 0)
            throw new ConflictException("Google sign-in is not available yet. Use email and password.");
        try
        {
            var payload = await GoogleJsonWebSignature.ValidateAsync(idToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = audiences }).WaitAsync(cancellationToken);
            if (!payload.EmailVerified || string.IsNullOrWhiteSpace(payload.Subject) || payload.Subject.Length > 255
                || string.IsNullOrWhiteSpace(payload.Email) || payload.Email.Length > 255
                || !System.Net.Mail.MailAddress.TryCreate(payload.Email, out _))
                throw new ForbiddenException("Google could not verify this account. Please choose another sign-in method.");
            var avatar = Uri.TryCreate(payload.Picture, UriKind.Absolute, out var picture) && picture.Scheme == Uri.UriSchemeHttps
                && payload.Picture.Length <= 500 ? payload.Picture : null;
            return new GoogleIdentity(payload.Subject, payload.Email, payload.Name, avatar);
        }
        catch (InvalidJwtException)
        {
            throw new ForbiddenException("Your Google sign-in expired or could not be verified. Please try again.");
        }
        catch (HttpRequestException)
        {
            throw new ConflictException("Cannot reach Google right now. Please try again or use email and password.");
        }
    }
}
