using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class ReportRepaymentRequestValidator:AbstractValidator<ReportRepaymentRequest> {public ReportRepaymentRequestValidator(){
RuleFor(x=>x.ClientRequestId).NotEmpty();RuleFor(x=>x.Amount).GreaterThan(0).LessThanOrEqualTo(SupplyConstants.MaxMoney).Must(x=>decimal.Truncate(x)==x);RuleFor(x=>x.Reference).NotNull().MaximumLength(300);
}}
