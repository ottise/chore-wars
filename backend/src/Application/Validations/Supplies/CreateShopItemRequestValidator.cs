using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;

namespace ChoreWars.Application.Validations.Supplies;

public sealed class CreateShopItemRequestValidator : AbstractValidator<CreateShopItemRequest>
{
    public CreateShopItemRequestValidator()
    {
        RuleFor(x => x.ClientRequestId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Unit).NotEmpty().MaximumLength(40);
        RuleFor(x => x.ContactName).NotEmpty().MaximumLength(120);
        RuleFor(x => x.Price).GreaterThan(0).LessThanOrEqualTo(SupplyConstants.MaxMoney).Must(x => decimal.Truncate(x) == x);
        RuleFor(x => x.Phone).NotEmpty().MaximumLength(24).Matches(@"^\+?[0-9 ()\-]{6,24}$");
        RuleFor(x => x.Email).MaximumLength(254).EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email));
        RuleFor(x => x).Must(x => !string.IsNullOrWhiteSpace(x.Phone) || !string.IsNullOrWhiteSpace(x.Email))
            .WithMessage("Enter a phone number or email address.");
    }
}
