using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface IUserBankAccountService {
 Task<BankAccountResponse?> ReadAsync(Guid actor,CancellationToken ct);
 Task<BankAccountResponse> SaveAsync(Guid actor,UpsertBankAccountRequest request,CancellationToken ct);
}
