using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace ChoreWars.Infrastructure.Data;

public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    private const string DockerLocalFallback = "Host=localhost;Port=5435;Database=chorewars;Username=postgres;Password=postgres";

    public AppDbContext CreateDbContext(string[] args)
    {
        var builder = new DbContextOptionsBuilder<AppDbContext>();

        var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
            ?? DockerLocalFallback;

        builder.UseNpgsql(connectionString);

        return new AppDbContext(builder.Options);
    }
}
