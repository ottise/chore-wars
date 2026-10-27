using System.Security.Cryptography;
using System.Text;
using ChoreWars.Presentation.Health;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Options;

namespace ChoreWars.Presentation.Authorization;

public sealed class DeploymentHealthAuthorizationFilter(IOptions<DeploymentHealthOptions> options) : IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var expected = options.Value.Key;
        var supplied = context.HttpContext.Request.Headers[DeploymentHealthOptions.HeaderName].ToString();
        if (expected.Length < 32 || !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(supplied)))
            context.Result = new UnauthorizedResult();
    }
}
