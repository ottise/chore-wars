using FluentValidation;
using ChoreWars.Application.DTOs.User;

namespace ChoreWars.Application.Validations.User;

public class UpdateProfileRequestValidator : AbstractValidator<UpdateProfileRequest>
{
    public UpdateProfileRequestValidator()
    {
        RuleFor(x => x.DisplayName)
            .NotEmpty()
            .MaximumLength(50);
    }
}
