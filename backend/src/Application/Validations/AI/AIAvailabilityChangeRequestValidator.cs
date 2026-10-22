using ChoreWars.Application.DTOs.AI;
using FluentValidation;

namespace ChoreWars.Application.Validations.AI;

public sealed class AIAvailabilityChangeRequestValidator : AbstractValidator<AIAvailabilityChangeRequest>
{
    public AIAvailabilityChangeRequestValidator()
    {
        RuleFor(x=>x.ClientRequestId).NotEmpty();
        RuleFor(x=>x.SeasonId).NotEmpty();
        RuleFor(x=>x.LocalDate).NotEqual(default(DateOnly));
        RuleFor(x=>x.StartMinute).InclusiveBetween(0,1439);
        RuleFor(x=>x.EndMinute).InclusiveBetween(1,1440).GreaterThan(x=>x.StartMinute);
    }
}
