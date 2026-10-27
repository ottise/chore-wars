using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class DeploymentSchemaTests
{
    [PostgresFact]
    public async Task MissingRequiredTableFailsWithoutRepairingIt()
    {
        await using var fixture = await PostgresFixture.CreateAsync();
        await using var scope = fixture.Services.CreateAsyncScope();
        var checker = scope.ServiceProvider.GetRequiredService<IDatabaseSchemaStatus>();
        Assert.True((await checker.CheckAsync()).Ready);
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.ExecuteSqlRawAsync("DROP TABLE \"AIChatInsights\"");
        var status = await checker.CheckAsync();
        Assert.False(status.Ready);
        Assert.Contains("AIChatInsights", status.MissingTables);
        Assert.False((await checker.CheckAsync()).Ready);
    }
}
