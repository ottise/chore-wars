using FluentValidation;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Common.Constants;

namespace ChoreWars.Application.Validations.Chore;

public class CreateChoreRequestValidator : AbstractValidator<CreateChoreRequest>
{
    public CreateChoreRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.KarmaPoints)
            .InclusiveBetween(KarmaConstants.MinKarmaPoints, KarmaConstants.MaxKarmaPoints);

        RuleFor(x => x.Type)
            .IsInEnum();

        RuleFor(x => x.FrequencyType)
            .IsInEnum();

        RuleFor(x => x.FrequencyValue)
            .GreaterThan(0)
            .When(x => x.FrequencyType == FrequencyType.EVERY_X_DAYS || 
                       x.FrequencyType == FrequencyType.X_TIMES_PER_WEEK ||
                       x.FrequencyType == FrequencyType.EVERY_X_MONTHS);
                       
        RuleFor(x => x.FrequencyDays)
            .NotEmpty()
            .When(x => x.FrequencyType == FrequencyType.SPECIFIC_DAYS)
            .WithMessage("FrequencyDays must be provided for SPECIFIC_DAYS frequency type.");
    }
}
