using ChoreWars.Application.DTOs.AI;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;

namespace ChoreWars.Application.Validations.AI;

public sealed class AIObservationRequestValidator : AbstractValidator<AIObservationRequest>
{
    public AIObservationRequestValidator()
    {
        RuleFor(x=>x.ClientRequestId).NotEmpty();
        RuleFor(x=>x.EntityId).NotEmpty();
        RuleFor(x=>x.Kind).Must(x=>x is AIObservationKinds.TaskOpened or AIObservationKinds.BountyOpened);
    }
}
