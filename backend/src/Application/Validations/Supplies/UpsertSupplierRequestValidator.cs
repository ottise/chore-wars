using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class UpsertSupplierRequestValidator:AbstractValidator<UpsertSupplierRequest> {public UpsertSupplierRequestValidator(){
RuleFor(x=>x.Name).NotEmpty().MaximumLength(120);RuleFor(x=>x.Phone).MaximumLength(24);RuleFor(x=>x.Email).MaximumLength(254).EmailAddress().When(x=>!string.IsNullOrWhiteSpace(x.Email));RuleFor(x=>x.DeliveryArea).NotEmpty().MaximumLength(300);RuleFor(x=>x.DeliveryFee).InclusiveBetween(0,SupplyConstants.MaxMoney).Must(x=>decimal.Truncate(x)==x);
}}
