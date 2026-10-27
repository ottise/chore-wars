using ChoreWars.Application.DTOs.Supplies;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class CreateSupplyDisputeRequestValidator:AbstractValidator<CreateSupplyDisputeRequest>{public CreateSupplyDisputeRequestValidator(){RuleFor(x=>x.ClientRequestId).NotEmpty();RuleFor(x=>x.Reason).NotEmpty().MaximumLength(500);}}
