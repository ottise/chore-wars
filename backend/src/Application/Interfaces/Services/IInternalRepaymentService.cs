using ChoreWars.Application.DTOs.Supplies;
namespace ChoreWars.Application.Interfaces.Services;
public interface IInternalRepaymentService
{
 Task<PurchaseDebtSummaryResponse> SummaryAsync(Guid house,Guid actor,CancellationToken ct);
 Task<PurchaseDebtResponse> ReadAsync(Guid id,Guid actor,CancellationToken ct);
 Task<PurchaseDebtResponse> ReportAsync(Guid id,Guid actor,ReportRepaymentRequest request,CancellationToken ct);
 Task<PurchaseDebtResponse> RespondAsync(Guid id,Guid repayment,Guid actor,ConfirmRepaymentRequest request,CancellationToken ct);
 Task<RepaymentInstructionsResponse> InstructionsAsync(Guid id,Guid actor,CancellationToken ct);
}
