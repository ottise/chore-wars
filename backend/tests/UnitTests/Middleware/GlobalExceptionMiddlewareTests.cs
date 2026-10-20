using System.Text.Json;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Presentation.Middleware;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;

namespace UnitTests.Middleware;

public class GlobalExceptionMiddlewareTests
{
    [Fact]
    public async Task InvokeAsync_ForForbiddenException_ReturnsCamelCaseProblemDetails()
    {
        var middleware = new GlobalExceptionMiddleware(
            _ => throw new ForbiddenException("Only the house owner can generate a schedule."),
            NullLogger<GlobalExceptionMiddleware>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);

        context.Response.Body.Position = 0;
        using var json = await JsonDocument.ParseAsync(context.Response.Body);
        Assert.Equal(StatusCodes.Status403Forbidden, context.Response.StatusCode);
        Assert.Equal("application/problem+json", context.Response.ContentType);
        Assert.Equal(
            "Only the house owner can generate a schedule.",
            json.RootElement.GetProperty("detail").GetString());
        Assert.True(json.RootElement.TryGetProperty("traceId", out _));
    }

    [Fact]
    public async Task InvokeAsync_ForUnexpectedException_DoesNotLeakInternalDetails()
    {
        var middleware = new GlobalExceptionMiddleware(
            _ => throw new InvalidOperationException("database password was exposed"),
            NullLogger<GlobalExceptionMiddleware>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);

        context.Response.Body.Position = 0;
        using var json = await JsonDocument.ParseAsync(context.Response.Body);
        Assert.Equal(StatusCodes.Status500InternalServerError, context.Response.StatusCode);
        Assert.DoesNotContain(
            "password",
            json.RootElement.GetProperty("detail").GetString(),
            StringComparison.OrdinalIgnoreCase);
    }
}
