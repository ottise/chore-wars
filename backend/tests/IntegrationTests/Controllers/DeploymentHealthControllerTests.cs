using System.Net;
using IntegrationTests.Infrastructure;

namespace IntegrationTests.Controllers;

public class DeploymentHealthControllerTests
{
    [PostgresFact]
    public async Task VersionIsPublicAndDeploymentDetailsRequireSeparateKey()
    {
        await using var fixture = await PostgresFixture.CreateAsync();
        await using var app = new ApiFactory(fixture);
        using var client = app.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health/version")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health/ready")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/deployment/health")).StatusCode);
    }
}
