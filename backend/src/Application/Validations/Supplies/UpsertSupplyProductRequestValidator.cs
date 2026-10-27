using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class UpsertSupplyProductRequestValidator:AbstractValidator<UpsertSupplyProductRequest> {public UpsertSupplyProductRequestValidator(){
RuleFor(x=>x.Sku).NotEmpty().MaximumLength(40);RuleFor(x=>x.Name).NotEmpty().MaximumLength(150);RuleFor(x=>x.Unit).NotEmpty().MaximumLength(40);RuleFor(x=>x.Price).GreaterThan(0).LessThanOrEqualTo(SupplyConstants.MaxMoney).Must(x=>decimal.Truncate(x)==x);RuleFor(x=>x.AvailableQuantity).InclusiveBetween(0,1_000_000);
}}
