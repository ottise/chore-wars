namespace ChoreWars.Infrastructure.Diagnostics;

// Production implementation is deliberately inert. Integration hosts replace it via DI.
public interface IRuntimeProbe
{
    Task HitAsync(string point, CancellationToken ct);
}
public sealed class NoopRuntimeProbe : IRuntimeProbe
{
    public Task HitAsync(string point, CancellationToken ct) => Task.CompletedTask;
}
