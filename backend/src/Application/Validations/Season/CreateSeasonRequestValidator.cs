using FluentValidation;
using ChoreWars.Application.DTOs.Season;

namespace ChoreWars.Application.Validations.Season;

public class CreateSeasonRequestValidator : AbstractValidator<CreateSeasonRequest>
{
    public CreateSeasonRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.StartDate)
            .LessThan(x => x.EndDate).WithMessage("StartDate must be before EndDate.");
            
        RuleFor(x => x.AllocationMethod)
            .IsInEnum();
    }
}
