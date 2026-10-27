using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class SupplyRefundRequestValidator:AbstractValidator<SupplyRefundRequest>{public SupplyRefundRequestValidator(){
 RuleFor(x=>x.ClientRequestId).NotEmpty();RuleFor(x=>x.Amount).GreaterThan(0).LessThanOrEqualTo(SupplyConstants.MaxMoney).Must(x=>decimal.Truncate(x)==x);
 RuleFor(x=>x.Reference).NotEmpty().MaximumLength(300);RuleFor(x=>x.Reason).NotEmpty().MaximumLength(500);
}}
