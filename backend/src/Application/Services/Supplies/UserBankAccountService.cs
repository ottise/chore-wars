using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using FluentValidation;
namespace ChoreWars.Application.Services.Supplies;
public sealed class UserBankAccountService(ISupplyRepository store,IHouseMutationCoordinator mutations,IValidator<UpsertBankAccountRequest> validator):IUserBankAccountService {
 public static BankAccountResponse Map(UserBankAccount x)=>new(x.Id,x.BankName,x.AccountNumber,x.AccountName,x.Active,x.Version);
 public async Task<BankAccountResponse?> ReadAsync(Guid actor,CancellationToken ct){var x=await store.BankAsync(actor,ct);return x==null?null:Map(x);}
 public async Task<BankAccountResponse> SaveAsync(Guid actor,UpsertBankAccountRequest r,CancellationToken ct){
  await validator.ValidateAndThrowAsync(r,ct);
  return await mutations.RunAsync(actor,async()=>{
   var x=await store.BankAsync(actor,ct);if(x==null){x=new UserBankAccount{Id=Guid.NewGuid(),UserId=actor};store.Add(x);}
   x.BankName=r.BankName.Trim();x.AccountName=r.AccountName.Trim();x.AccountNumber=r.AccountNumber.Trim();x.Active=r.Active;x.Version++;
   return Map(x);
  },ct);
 }
}
