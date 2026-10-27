using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Domain.Common.Constants;
using FluentValidation;
namespace ChoreWars.Application.Validations.Supplies;
public sealed class UpsertBankAccountRequestValidator:AbstractValidator<UpsertBankAccountRequest> {public UpsertBankAccountRequestValidator(){
RuleFor(x=>x.BankName).NotEmpty().MaximumLength(100);RuleFor(x=>x.AccountNumber).NotEmpty().Matches("^[0-9]{4,40}$");RuleFor(x=>x.AccountName).NotEmpty().MaximumLength(150);
}}
