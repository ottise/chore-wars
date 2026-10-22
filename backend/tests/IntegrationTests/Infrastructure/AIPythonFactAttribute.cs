namespace IntegrationTests.Infrastructure;

public sealed class AIPythonFactAttribute : FactAttribute
{
    public AIPythonFactAttribute()
    {
        if(string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_POSTGRES")) || string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_AI_URL")) || string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CHOREWARS_TEST_AI_KEY")))
            Skip="Configure disposable PostgreSQL and the private local Python AI test server.";
    }
}
