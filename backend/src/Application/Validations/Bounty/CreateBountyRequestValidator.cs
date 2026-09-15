using FluentValidation;
using ChoreWars.Application.DTOs.Bounty;

namespace ChoreWars.Application.Validations.Bounty;

public class CreateBountyRequestValidator : AbstractValidator<CreateBountyRequest>
{
    public CreateBountyRequestValidator()
    {
        RuleFor(x => x.ChoreOccurrenceId)
            .NotEmpty().WithMessage("ChoreOccurrenceId is required.");

        RuleFor(x => x.Amount)
            .GreaterThan(0).WithMessage("Bounty amount must be greater than zero.");
    }
}
