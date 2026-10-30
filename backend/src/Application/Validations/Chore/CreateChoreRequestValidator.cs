using FluentValidation;
using ChoreWars.Application.DTOs.Chore;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Common.Constants;

namespace ChoreWars.Application.Validations.Chore;

public class CreateChoreRequestValidator : AbstractValidator<CreateChoreRequest>
{
    public CreateChoreRequestValidator()
    {
        RuleFor(x => x.ClientRequestId).Must(id => id != Guid.Empty).When(x => x.ClientRequestId.HasValue);
        RuleFor(x => x.ExpectedRevision).GreaterThanOrEqualTo(0).When(x => x.ExpectedRevision.HasValue);
        RuleFor(x => x.Difficulty).IsInEnum();
        RuleFor(x => x.DeadlineMinutes).InclusiveBetween(0,1439);
        RuleFor(x => x.CustomDates).NotNull();
        RuleFor(x => x.CustomDates).NotEmpty().When(x=>x.FrequencyType==FrequencyType.CUSTOM);
        RuleFor(x => x.FrequencyDays).Must(days=>days==null||days.All(day=>Enum.IsDefined(day))).WithMessage("Invalid weekday.");
        RuleFor(x => x.FrequencyValue).NotNull().GreaterThan(0).When(x=>x.FrequencyType==FrequencyType.EVERY_X_DAYS||x.FrequencyType==FrequencyType.EVERY_X_MONTHS||x.FrequencyType==FrequencyType.X_TIMES_PER_WEEK);
        RuleFor(x => x.FrequencyDays).Must(days=>days!=null&&days.Distinct().Count()>0).When(x=>x.FrequencyType==FrequencyType.SPECIFIC_DAYS||x.FrequencyType==FrequencyType.X_TIMES_PER_WEEK);
        RuleFor(x => x.FrequencyDays).Must((request,days)=>days!=null&&days.Distinct().Count()==request.FrequencyValue).When(x=>x.FrequencyType==FrequencyType.X_TIMES_PER_WEEK);
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
