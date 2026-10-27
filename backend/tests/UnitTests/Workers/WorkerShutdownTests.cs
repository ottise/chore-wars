using ChoreWars.Infrastructure.Workers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Moq;

namespace UnitTests.Workers;

public sealed class WorkerShutdownTests
{
    public static TheoryData<string> Workers => new() { "bounty", "overdue", "season", "allocation", "reminder" };

    private static BackgroundService Create(string kind, IServiceScopeFactory scopes, ILoggerFactory logs) => kind switch {
        "bounty" => new BountyExpirationWorker(logs.CreateLogger<BountyExpirationWorker>(), scopes),
        "overdue" => new OverdueChoreWorker(logs.CreateLogger<OverdueChoreWorker>(), scopes),
        "season" => new SeasonEndWorker(logs.CreateLogger<SeasonEndWorker>(), scopes),
        "allocation" => new ChoreAllocationWorker(logs.CreateLogger<ChoreAllocationWorker>(), scopes),
        "reminder" => new DeadlineReminderWorker(logs.CreateLogger<DeadlineReminderWorker>(), scopes),
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    [Theory, MemberData(nameof(Workers))]
    public async Task StopDuringDelayCompletesNormallyAndStillReportsRealWorkErrors(string kind)
    {
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var scopes = new Mock<IServiceScopeFactory>();
        scopes.Setup(s => s.CreateScope()).Callback(() => entered.TrySetResult()).Throws(new InvalidOperationException("Test work failure"));
        var logger = new Mock<ILogger>();
        var logs = new Mock<ILoggerFactory>();
        logs.Setup(l => l.CreateLogger(It.IsAny<string>())).Returns(logger.Object);
        using var worker = Create(kind, scopes.Object, logs.Object);
        await worker.StartAsync(default);
        await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await worker.StopAsync(default).WaitAsync(TimeSpan.FromSeconds(5));
        await worker.ExecuteTask!;
        Assert.Equal(TaskStatus.RanToCompletion, worker.ExecuteTask!.Status);
        logger.Verify(l => l.Log(LogLevel.Error, It.IsAny<EventId>(), It.IsAny<It.IsAnyType>(), It.IsAny<Exception>(), It.IsAny<Func<It.IsAnyType, Exception?, string>>()), Times.Once);
    }

    [Theory, MemberData(nameof(Workers))]
    public async Task ShutdownCancellationDuringScopeResolutionDoesNotFaultOrLogAnError(string kind)
        => await CancelDuringWork(kind, false);

    [Theory, MemberData(nameof(Workers))]
    public async Task DisposedScopeDuringShutdownDoesNotFaultOrLogAnError(string kind)
        => await CancelDuringWork(kind, true);

    private static async Task CancelDuringWork(string kind, bool disposed)
    {
        using var shutdown = new CancellationTokenSource();
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var scopes = new Mock<IServiceScopeFactory>();
        scopes.Setup(s => s.CreateScope()).Returns(() => {
            entered.TrySetResult();
            if (!shutdown.Token.WaitHandle.WaitOne(TimeSpan.FromSeconds(5))) throw new TimeoutException("Test did not initiate shutdown.");
            if (disposed) throw new ObjectDisposedException("test scope");
            throw new OperationCanceledException(shutdown.Token);
        });
        var logger = new Mock<ILogger>();
        var logs = new Mock<ILoggerFactory>();
        logs.Setup(l => l.CreateLogger(It.IsAny<string>())).Returns(logger.Object);
        using var worker = Create(kind, scopes.Object, logs.Object);
        await worker.StartAsync(shutdown.Token);
        await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        shutdown.Cancel();
        await worker.StopAsync(default).WaitAsync(TimeSpan.FromSeconds(5));
        await worker.ExecuteTask!;
        Assert.Equal(TaskStatus.RanToCompletion, worker.ExecuteTask!.Status);
        logger.Verify(l => l.Log(LogLevel.Error, It.IsAny<EventId>(), It.IsAny<It.IsAnyType>(), It.IsAny<Exception>(), It.IsAny<Func<It.IsAnyType, Exception?, string>>()), Times.Never);
    }
}
