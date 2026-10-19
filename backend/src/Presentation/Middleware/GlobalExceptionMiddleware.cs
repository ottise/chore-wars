using System;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using ChoreWars.Domain.Exceptions;
using ValidationException = ChoreWars.Domain.Exceptions.ValidationException;

namespace ChoreWars.Presentation.Middleware;

public class GlobalExceptionMiddleware
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            _logger.LogInformation("Request {Method} {Path} was cancelled by the client.",
                context.Request.Method, context.Request.Path);
        }
        catch (Exception ex)
        {
            if (ex is DomainException)
            {
                _logger.LogWarning("Request {Method} {Path} failed: {Message}",
                    context.Request.Method, context.Request.Path, ex.Message);
            }
            else
            {
                _logger.LogError(ex, "Unhandled exception for {Method} {Path}.",
                    context.Request.Method, context.Request.Path);
            }

            if (context.Response.HasStarted)
                throw;

            await HandleExceptionAsync(context, ex);
        }
    }

    private static Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/problem+json";

        var statusCode = exception switch
        {
            NotFoundException => (int)HttpStatusCode.NotFound,
            ForbiddenException => (int)HttpStatusCode.Forbidden,
            ConflictException => (int)HttpStatusCode.Conflict,
            ValidationException => (int)HttpStatusCode.BadRequest,
            DomainException => (int)HttpStatusCode.BadRequest,
            BadHttpRequestException => (int)HttpStatusCode.BadRequest,
            UnauthorizedAccessException => (int)HttpStatusCode.Unauthorized,
            _ => (int)HttpStatusCode.InternalServerError
        };

        context.Response.StatusCode = statusCode;

        var problemDetails = new Microsoft.AspNetCore.Mvc.ProblemDetails
        {
            Status = statusCode,
            Title = GetTitle(statusCode),
            Detail = statusCode == (int)HttpStatusCode.InternalServerError
                ? "An unexpected server error occurred. Please try again."
                : exception.Message,
            Instance = context.Request.Path
        };

        problemDetails.Extensions["traceId"] = context.TraceIdentifier;

        if (exception is ValidationException validationException)
        {
            problemDetails.Extensions["errors"] = validationException.Errors;
        }

        return context.Response.WriteAsync(JsonSerializer.Serialize(problemDetails, JsonOptions));
    }

    private static string GetTitle(int statusCode) => statusCode switch
    {
        (int)HttpStatusCode.BadRequest => "Invalid request",
        (int)HttpStatusCode.Unauthorized => "Authentication required",
        (int)HttpStatusCode.Forbidden => "Permission denied",
        (int)HttpStatusCode.NotFound => "Resource not found",
        (int)HttpStatusCode.Conflict => "Request conflict",
        _ => "Server error"
    };
}
