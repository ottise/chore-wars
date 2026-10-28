using ChoreWars.Application.DTOs.Auth;
using FluentValidation;

namespace ChoreWars.Application.Validations.Auth;

public sealed class GoogleLoginRequestValidator : AbstractValidator<GoogleLoginRequest>
{
    public GoogleLoginRequestValidator() => RuleFor(x => x.IdToken).NotEmpty().MaximumLength(16384);
}
