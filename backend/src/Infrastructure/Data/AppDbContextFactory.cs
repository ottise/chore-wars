using System.IO;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace ChoreWars.Infrastructure.Data;

public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var builder = new DbContextOptionsBuilder<AppDbContext>();
        var connectionString = "Host=localhost;Port=5435;Database=chorewars;Username=postgres;Password=postgres";

        builder.UseNpgsql(connectionString);

        return new AppDbContext(builder.Options);
    }
}
