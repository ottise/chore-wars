using ChoreWars.Application.DTOs.AI;
using FluentValidation;

namespace ChoreWars.Application.Validations.AI;

public sealed class AIGenerateRequestValidator : AbstractValidator<AIGenerateRequest>
{
    public AIGenerateRequestValidator()
    {
        RuleFor(x=>x.ClientRequestId).NotEmpty();
        RuleFor(x=>x.SeasonId).NotEmpty();
        RuleFor(x=>x.Text).MaximumLength(8000);
        RuleFor(x=>x.ParticipantIds).Cascade(CascadeMode.Stop).NotNull().Must(x=>x.Count<=50);
        RuleFor(x=>x.Resources).Cascade(CascadeMode.Stop).NotNull().Must(x=>x.Count<=30);
        RuleForEach(x=>x.Resources).NotEmpty().MaximumLength(200);
        RuleFor(x=>x.AvailabilityChanges).Cascade(CascadeMode.Stop).NotNull().Must(x=>x.Count<=31);
    }
}
