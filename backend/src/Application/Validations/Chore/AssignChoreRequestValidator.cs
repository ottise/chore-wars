using FluentValidation;
using ChoreWars.Application.DTOs.Chore;

namespace ChoreWars.Application.Validations.Chore;

public class AssignChoreRequestValidator : AbstractValidator<AssignChoreRequest>
{
    public AssignChoreRequestValidator()
    {
        RuleFor(x => x.UserId)
            .NotEmpty();
    }
}
