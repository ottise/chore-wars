using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Options;
namespace ChoreWars.Infrastructure.Payments;
public sealed class SupplierOperatorAccess(IOptions<PayOsOptions> options) : ISupplierOperatorAccess
{
    public bool CanOperate(Guid actor) => actor != Guid.Empty && options.Value.OperatorUserId == actor;
}
