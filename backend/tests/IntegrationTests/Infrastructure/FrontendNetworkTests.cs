using System.Diagnostics;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public sealed class FrontendNetworkFactAttribute : FactAttribute
{
    public FrontendNetworkFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("CHOREWARS_TEST_POSTGRES")) ||
            string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("CHOREWARS_TEST_FLUTTER")))
            Skip = "Set CHOREWARS_TEST_FLUTTER to run the real Flutter-to-Kestrel contract suite.";
    }
}

public sealed class FrontendNetworkTests
{
    [FrontendNetworkFact]
    public async Task FlutterRepositoriesAndSignalRUseRealBackendContracts()
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root != null && !Directory.Exists(Path.Combine(root.FullName, "mobile"))) root = root.Parent;
        Assert.NotNull(root);
        var scratch = Path.Combine(root!.FullName, "artifacts", "runtime", "frontend-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(scratch);
        await using var database = await PostgresFixture.CreateAsync();
        await File.WriteAllTextAsync(Path.Combine(scratch, "appsettings.json"), JsonSerializer.Serialize(new
        {
            ConnectionStrings = new { DefaultConnection = database.ConnectionString },
            Jwt = new { Secret = "integration-test-signing-secret-at-least-sixty-four-characters-long-2026", Issuer = "ChoreWarsTest", Audience = "ChoreWarsTestUsers" },
            Logging = new { LogLevel = new { Default = "Warning" } }
        }));
        await using var source = new ApiFactory(database);
        await using var factory = source.WithWebHostBuilder(builder => builder.UseContentRoot(scratch));
        factory.UseKestrel(0);
        using var client = factory.CreateClient();
        (await client.GetAsync("/health/ready")).EnsureSuccessStatusCode();
        var address = factory.Services.GetRequiredService<IServer>().Features
            .Get<IServerAddressesFeature>()!.Addresses.Single();
        var flutter = Environment.GetEnvironmentVariable("CHOREWARS_TEST_FLUTTER")!;
        var start = new ProcessStartInfo(OperatingSystem.IsWindows() ? "cmd.exe" : flutter)
        {
            WorkingDirectory = Path.Combine(root!.FullName, "mobile"),
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true
        };
        if (OperatingSystem.IsWindows())
        {
            start.ArgumentList.Add("/d"); start.ArgumentList.Add("/c"); start.ArgumentList.Add(flutter);
        }
        foreach (var arg in new[] { "test", "test/live/backend_network_test.dart", "--reporter", "expanded" }) start.ArgumentList.Add(arg);
        start.Environment["CHOREWARS_LIVE_API"] = address.TrimEnd('/') + "/api";
        using var process = Process.Start(start)!;
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        try { await process.WaitForExitAsync().WaitAsync(TimeSpan.FromMinutes(8)); }
        finally { if (!process.HasExited) process.Kill(entireProcessTree: true); }
        var output = await stdout + await stderr;
        var artifact = Path.Combine(root.FullName, "artifacts", "ci", "frontend-network.log");
        Directory.CreateDirectory(Path.GetDirectoryName(artifact)!);
        await File.WriteAllTextAsync(artifact, output);
        Assert.True(process.ExitCode == 0, output);
    }
}
