using ChoreWars.Application.DTOs.House;
using FluentValidation;

namespace ChoreWars.Application.Validations.House;

public class UpdateHouseNameRequestValidator : AbstractValidator<UpdateHouseNameRequest>
{
    public UpdateHouseNameRequestValidator()
    {
        RuleFor(request => request.Name)
            .NotEmpty()
            .MaximumLength(100);
    }
}
