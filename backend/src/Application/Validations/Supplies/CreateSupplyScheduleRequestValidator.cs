using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class CreateSupplyScheduleRequestValidator:AbstractValidator<CreateSupplyScheduleRequest> {public CreateSupplyScheduleRequestValidator(){
RuleFor(x=>x.ClientRequestId).NotEmpty();RuleFor(x=>x.Items).NotEmpty().MaximumLength(500);RuleFor(x=>x.DayOfMonth).InclusiveBetween(1,31);RuleFor(x=>x.Hour).InclusiveBetween(0,23);RuleFor(x=>x.Minute).InclusiveBetween(0,59);RuleFor(x=>x.QuietFromHour).InclusiveBetween(0,23);RuleFor(x=>x.QuietToHour).InclusiveBetween(0,23);
}}
