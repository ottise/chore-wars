using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class ConfirmRepaymentRequestValidator:AbstractValidator<ConfirmRepaymentRequest> {public ConfirmRepaymentRequestValidator(){
RuleFor(x=>x.Reason).MaximumLength(500);RuleFor(x=>x.Reason).NotEmpty().When(x=>!x.Confirm);
}}
