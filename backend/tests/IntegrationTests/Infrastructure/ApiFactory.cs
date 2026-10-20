using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
namespace IntegrationTests.Infrastructure;
public sealed class ApiFactory(PostgresFixture database) : WebApplicationFactory<Program> {
    protected override void ConfigureWebHost(IWebHostBuilder builder) {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_,config)=>config.AddInMemoryCollection(new Dictionary<string,string?> {
            ["ConnectionStrings:DefaultConnection"]=database.ConnectionString,
            ["Jwt:Secret"]="integration-test-signing-secret-at-least-sixty-four-characters-long-2026",
            ["Jwt:Issuer"]="ChoreWarsTest", ["Jwt:Audience"]="ChoreWarsTestUsers"
        }));
        builder.ConfigureTestServices(services=>{
            services.RemoveAll<IHostedService>();
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(options=>options.UseNpgsql(database.ConnectionString));
        });
    }
}
