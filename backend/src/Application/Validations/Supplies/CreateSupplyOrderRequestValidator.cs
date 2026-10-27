using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class CreateSupplyOrderRequestValidator:AbstractValidator<CreateSupplyOrderRequest> {public CreateSupplyOrderRequestValidator(){
RuleFor(x=>x.ClientRequestId).NotEmpty();RuleFor(x=>x.SupplierId).NotEmpty();RuleFor(x=>x.PayerUserId).NotEmpty();
RuleFor(x=>x.DeliveryAddress).NotEmpty().MaximumLength(500);RuleFor(x=>x.ContactPhone).NotEmpty().MaximumLength(24);
RuleFor(x=>x.Lines).NotEmpty().Must(x=>x!=null && x.All(y=>y!=null) && x.Count<=SupplyConstants.MaxLines && x.Select(y=>y.ProductId).Distinct().Count()==x.Count);
RuleForEach(x=>x.Lines).ChildRules(v=>{v.RuleFor(x=>x.ProductId).NotEmpty();v.RuleFor(x=>x.Quantity).InclusiveBetween(1,SupplyConstants.MaxQuantity);});
RuleFor(x=>x.Shares).NotEmpty().Must(x=>x!=null && x.All(y=>y!=null) && x.Count<=SupplyConstants.MaxMembers && x.Select(y=>y.UserId).Distinct().Count()==x.Count);
RuleFor(x=>x).Must(x=>x.Shares!=null&&x.Shares.Any(y=>y!=null&&y.UserId==x.PayerUserId)).WithMessage("The payer must be a participant and explicitly approve advancing the money.");
RuleForEach(x=>x.Shares).ChildRules(v=>{v.RuleFor(x=>x.UserId).NotEmpty();v.RuleFor(x=>x.Amount).Must(x=>x==null||(x>=0&&x<=SupplyConstants.MaxMoney&&decimal.Truncate(x.Value)==x));});
}}
