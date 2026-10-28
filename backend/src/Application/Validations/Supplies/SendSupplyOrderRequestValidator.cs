using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class SendSupplyOrderRequestValidator : AbstractValidator<SendSupplyOrderRequest>
{
    public SendSupplyOrderRequestValidator()
    {
        RuleFor(x => x.ClientRequestId).NotEmpty();
        RuleFor(x => x.SupplierId).NotEmpty();
        RuleFor(x => x.Lines).NotEmpty().Must(x => x != null && x.Count <= SupplyConstants.MaxLines && x.All(y => y != null) && x.Select(y => y.ProductId).Distinct().Count() == x.Count);
        RuleForEach(x => x.Lines).ChildRules(v => { v.RuleFor(x => x.ProductId).NotEmpty(); v.RuleFor(x => x.Quantity).InclusiveBetween(1, SupplyConstants.MaxQuantity); });
        RuleFor(x => x.DeliveryAddress).NotNull().MaximumLength(500);
        RuleFor(x => x.ContactPhone).NotNull().MaximumLength(24);
        RuleFor(x => x.Note).NotNull().MaximumLength(1000);
    }
}
