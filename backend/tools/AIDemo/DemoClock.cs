namespace AIDemo;

public sealed class DemoClock(DateTimeOffset initial) : TimeProvider
{
    private DateTimeOffset _now=initial;
    public override DateTimeOffset GetUtcNow()=>_now;
    public void Set(DateTimeOffset value) {
        if(value<_now)throw new InvalidOperationException("Demo clock must never move backwards.");
        _now=value;
    }
}
