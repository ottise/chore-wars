using System.Security.Claims;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Mvc.Filters;
namespace ChoreWars.Presentation.Filters;
public sealed class HouseScopeFilter(IHouseAccessService access) : IAsyncActionFilter {
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next) {
        var route = context.RouteData.Values;
        if (Guid.TryParse(route.GetValueOrDefault("houseId")?.ToString(), out var houseId)) {
            var user = context.HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (Guid.TryParse(user,out var userId)) {
                var ct = context.HttpContext.RequestAborted;
                await access.EnsureActiveAsync(houseId,userId,ct);
                if (context.HttpContext.Request.Method is not ("GET" or "HEAD" or "OPTIONS")) await access.EnsureWritableAsync(houseId,ct);
                foreach (var kind in new[] { "seasonId", "choreId", "occurrenceId", "paymentId", "bountyId" })
                    if (Guid.TryParse(route.GetValueOrDefault(kind)?.ToString(),out var id)) await access.EnsureEntityScopeAsync(houseId,kind,id,ct);
            }
        }
        await next();
    }
}
