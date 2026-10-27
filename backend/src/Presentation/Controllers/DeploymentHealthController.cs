using System.Text.RegularExpressions;
using ChoreWars.Application.DTOs.Deployment;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Presentation.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace ChoreWars.Presentation.Controllers;

[ApiController]
public sealed class DeploymentHealthController(IDependencyHealthService health, IConfiguration configuration) : ControllerBase
{
    private string Version => Regex.IsMatch(configuration["RENDER_GIT_COMMIT"] ?? configuration["BUILD_COMMIT"] ?? "", "^[a-fA-F0-9]{40}$")
        ? (configuration["RENDER_GIT_COMMIT"] ?? configuration["BUILD_COMMIT"])! : "unknown";

    [HttpGet("health/version")]
    public IActionResult VersionInfo() => Ok(new { sha = Version });

    [HttpGet("api/deployment/health")]
    [ServiceFilter(typeof(DeploymentHealthAuthorizationFilter))]
    public async Task<IActionResult> Dependencies(CancellationToken ct) =>
        Ok(new DeploymentHealthResponse(Version, await health.CheckAsync(ct)));
}
