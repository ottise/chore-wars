using ChoreWars.Infrastructure.Data;
using ChoreWars.Presentation.Extensions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
namespace IntegrationTests.Infrastructure;
public sealed class PostgresFactAttribute : FactAttribute {
    public PostgresFactAttribute() { if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_POSTGRES"))) Skip = "Set CHOREWARS_TEST_POSTGRES to a disposable local PostgreSQL server."; }
}
public sealed class PostgresFixture : IAsyncDisposable {
    public ServiceProvider Services { get; }
    public string ConnectionString => new NpgsqlConnectionStringBuilder(_admin) { Database = _database }.ConnectionString;
    private readonly string _admin;
    private readonly string _database;
    private PostgresFixture(string admin,string database,ServiceProvider services) { _admin=admin;_database=database;Services=services; }
    public static async Task<PostgresFixture> CreateAsync(Dictionary<string,string?>? settings = null, Action<IServiceCollection>? configure = null) {
        var source=Environment.GetEnvironmentVariable("CHOREWARS_TEST_POSTGRES") ?? throw new InvalidOperationException("Test server is required.");
        var connection=new NpgsqlConnectionStringBuilder(source);
        if (connection.Host is not ("127.0.0.1" or "localhost")) throw new InvalidOperationException("Integration tests require a disposable local server.");
        var admin=connection.ConnectionString;
        var name="cw_test_"+Guid.NewGuid().ToString("N");
        await using(var db=new NpgsqlConnection(admin)) { await db.OpenAsync(); await using var cmd=new NpgsqlCommand($"CREATE DATABASE \"{name}\"",db);await cmd.ExecuteNonQueryAsync(); }
        connection.Database=name;
        var values = settings ?? new Dictionary<string,string?>();
        values["ConnectionStrings:DefaultConnection"] = connection.ConnectionString;
        var config=new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        var services=new ServiceCollection();services.AddSingleton<IConfiguration>(config);services.AddLogging();services.AddInfrastructureServices(config);services.AddApplicationServices();
        configure?.Invoke(services);
        var provider=services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes=true });
        var fixture=new PostgresFixture(admin,name,provider);
        try { await using var scope=provider.CreateAsyncScope();await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();return fixture; }
        catch { await fixture.DisposeAsync();throw; }
    }
    public async ValueTask DisposeAsync() {
        await Services.DisposeAsync();
        await using var db=new NpgsqlConnection(_admin);await db.OpenAsync();
        await using var cmd=new NpgsqlCommand($"DROP DATABASE \"{_database}\" WITH (FORCE)",db);await cmd.ExecuteNonQueryAsync();
    }
}
