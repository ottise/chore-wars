using ChoreWars.Application.DTOs.Auth;
using ChoreWars.Application.Validations.Auth;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Auth;
using Microsoft.Extensions.Options;

namespace UnitTests.Services;

public class GoogleIdentityVerifierTests
{
    [Fact]
    public async Task DisabledOrUnconfiguredGoogleFailsClosed()
    {
        foreach (var config in new[] { new GoogleAuthOptions(), new GoogleAuthOptions { Enabled = true } })
            await Assert.ThrowsAsync<ConflictException>(() => new GoogleIdentityVerifier(Options.Create(config)).VerifyAsync("ignored", default));
    }

    [Fact]
    public async Task MalformedTokenIsRejectedWithoutLeakingSdkErrors()
    {
        var verifier = new GoogleIdentityVerifier(Options.Create(new GoogleAuthOptions { Enabled = true, ClientIds = ["test.apps.googleusercontent.com"] }));
        var error = await Assert.ThrowsAsync<ForbiddenException>(() => verifier.VerifyAsync("not-a-token", default));
        Assert.DoesNotContain("not-a-token", error.Message);
    }

    [Fact]
    public void TokenInputHasAnExplicitSizeLimit()
    {
        var validator = new GoogleLoginRequestValidator();
        Assert.False(validator.Validate(new GoogleLoginRequest("")).IsValid);
        Assert.False(validator.Validate(new GoogleLoginRequest(new string('x', 16385))).IsValid);
    }
}
