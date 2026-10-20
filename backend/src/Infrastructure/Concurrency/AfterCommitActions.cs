using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Infrastructure.Concurrency;
public sealed class AfterCommitActions(ILogger<AfterCommitActions> logger) : IAfterCommitActions {
    private readonly List<Func<Task>> _actions = [];
    public void Enqueue(Func<Task> action) => _actions.Add(action);
    public void Clear() => _actions.Clear();
    public async Task FlushAsync() {
        var actions = _actions.ToArray(); _actions.Clear();
        foreach(var action in actions) try { await action(); } catch(Exception ex) { logger.LogWarning(ex,"Realtime delivery failed after commit; persisted data is available on refresh."); }
    }
}
