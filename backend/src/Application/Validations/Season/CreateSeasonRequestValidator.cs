using FluentValidation;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Domain.Common.Constants;

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

        RuleFor(x => x.EndDate)
            .Must((request, endDate) => endDate <= request.StartDate.AddMonths(SeasonConstants.MaxDurationMonths) ||
                                        (endDate - request.StartDate).TotalDays <= SeasonConstants.MaxDurationDays)
            .WithMessage("Season duration cannot exceed 1 month.");
            
        RuleFor(x => x.AllocationMethod)
            .IsInEnum();
    }
}
