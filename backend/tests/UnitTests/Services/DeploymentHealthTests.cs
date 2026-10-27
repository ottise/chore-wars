using ChoreWars.Infrastructure.Diagnostics;
using ChoreWars.Presentation.Authorization;
using ChoreWars.Presentation.Health;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Options;
using Moq;

namespace UnitTests.Services;

public class DeploymentHealthTests
{
    [Fact]
    public void StaleAndStoppedWorkersCannotPass()
    {
        var clock = new Mock<TimeProvider>();
        var now = DateTimeOffset.UtcNow;
        clock.Setup(x => x.GetUtcNow()).Returns(now);
        var registry = new WorkerHealthRegistry(clock.Object);
        Assert.Empty(registry.Snapshot());
        registry.Heartbeat("test");
        Assert.Equal("pass", Assert.Single(registry.Snapshot()).State);
        clock.Setup(x => x.GetUtcNow()).Returns(now.AddMinutes(1));
        Assert.Equal("fail", Assert.Single(registry.Snapshot()).State);
        registry.Stopped("test");
        Assert.Empty(registry.Snapshot());
    }

    [Theory]
    [InlineData("", "")]
    [InlineData("configured-key-that-is-at-least-32-characters", "wrong")]
    public void MissingOrWrongDeploymentKeyIsDenied(string configured, string provided)
    {
        var http = new DefaultHttpContext();
        http.Request.Headers[DeploymentHealthOptions.HeaderName] = provided;
        var context = new AuthorizationFilterContext(new ActionContext(http, new RouteData(), new ActionDescriptor()), []);
        new DeploymentHealthAuthorizationFilter(Options.Create(new DeploymentHealthOptions { Key = configured })).OnAuthorization(context);
        Assert.IsType<UnauthorizedResult>(context.Result);
    }
}
