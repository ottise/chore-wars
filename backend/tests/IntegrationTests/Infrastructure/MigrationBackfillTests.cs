using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
namespace IntegrationTests.Infrastructure;
public class MigrationBackfillTests {
    [PostgresFact] public async Task LegacyRoutineKeepsEndOfDayAndGetsAnEmptyCustomCalendar() {
        await using var fixture=await PostgresFixture.CreateAsync();
        await using var scope=fixture.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var migrator=db.GetService<IMigrator>();
        await migrator.MigrateAsync("20261015131034_AddActionProposals");
        var house=Guid.NewGuid();var chore=Guid.NewGuid();var now=DateTime.UtcNow;
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"Houses\" (\"Id\",\"Name\",\"InviteCode\",\"CreatedAt\") VALUES ({house}, 'Legacy house','LEGACY01',{now})");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"Chores\" (\"Id\",\"HouseId\",\"Name\",\"Description\",\"KarmaPoints\",\"Type\",\"FrequencyType\",\"Difficulty\",\"EstimatedMinutes\") VALUES ({chore},{house},'Legacy routine','',10,'NORMAL','DAILY','MEDIUM',30)");
        await migrator.MigrateAsync();
        var routine=await db.Chores.SingleAsync(x=>x.Id==chore);
        Assert.Equal(1439,routine.DeadlineMinutes);Assert.Empty(routine.CustomDates);Assert.Null(routine.SourceTemplateId);
        Assert.Equal(10,routine.KarmaPoints);
    }
}
