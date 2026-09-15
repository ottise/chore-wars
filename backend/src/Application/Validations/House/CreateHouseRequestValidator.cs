using FluentValidation;
using ChoreWars.Application.DTOs.House;

namespace ChoreWars.Application.Validations.House;

public class CreateHouseRequestValidator : AbstractValidator<CreateHouseRequest>
{
    public CreateHouseRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("House name is required.")
            .MaximumLength(100);
    }
}
