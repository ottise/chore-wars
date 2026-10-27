using ChoreWars.Application.DTOs.Supplies;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class ProposeSupplyResolutionRequestValidator:AbstractValidator<ProposeSupplyResolutionRequest>{public ProposeSupplyResolutionRequestValidator(){RuleFor(x=>x.Resolution).NotEmpty().MaximumLength(500);}}
