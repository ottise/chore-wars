using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class MutationCrashTests
{
    [PostgresTheory]
    [InlineData("mutation.before-commit",false)]
    [InlineData("mutation.after-commit",true)]
    public async Task HardProcessCrashPreservesAtomicityAndSafeRetry(string boundary,bool committed)
    {
        await using var f=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(f);
        await using(var worker=WorkerProcessHarness.Start(f,"mutation",boundary,occurrence:seed.OccurrenceId,user:seed.Users[0])) {
            await worker.WaitForProbeAsync();await worker.KillAsync();
        }
        await using(var check=f.Services.CreateAsyncScope()) {
            var db=check.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(committed?1:0,await db.KarmaTransactions.CountAsync());
            Assert.Equal(committed?1:0,await db.OutboxMessages.CountAsync());
            Assert.Equal(committed?60:50,(await db.HouseMembers.SingleAsync(x=>x.UserId==seed.Users[0])).KarmaBalance);
        }
        await using(var retry=f.Services.CreateAsyncScope()) await retry.ServiceProvider.GetRequiredService<IChoreService>().CompleteChoreAsync(seed.OccurrenceId,null,seed.Users[0]);
        await using var read=f.Services.CreateAsyncScope();var readDb=read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1,await readDb.KarmaTransactions.CountAsync());Assert.Equal(1,await readDb.OutboxMessages.CountAsync());
        Assert.Equal(60,(await readDb.HouseMembers.SingleAsync(x=>x.UserId==seed.Users[0])).KarmaBalance);
    }
}
