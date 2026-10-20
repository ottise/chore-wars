namespace ChoreWars.Application.Interfaces.Services;
public interface IAfterCommitActions {
    void Enqueue(Func<Task> action);
    Task FlushAsync();
    void Clear();
}
