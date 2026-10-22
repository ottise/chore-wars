using ChoreWars.Application.DTOs.AI;
using FluentValidation;

namespace ChoreWars.Application.Validations.AI;

public sealed class AITextRequestValidator : AbstractValidator<AITextRequest>
{
    public AITextRequestValidator()=>RuleFor(x=>x.Text).NotEmpty().MaximumLength(8000);
}
