using Microsoft.AspNetCore.Http;

namespace Smi.Control.Auth;

/// <summary>
/// Bearer-token auth for /api/v1 (spec 7.1). Public paths: POST /api/v1/sessions, /health/*.
/// Session context is stored in HttpContext.Items for downstream endpoints.
/// 401 with code SESSION_EXPIRED covers missing/invalid/expired/revoked tokens without distinction.
/// </summary>
public sealed class AuthMiddleware
{
    private readonly RequestDelegate _next;
    public AuthMiddleware(RequestDelegate next) { _next = next; }

    public async Task InvokeAsync(HttpContext ctx, SessionService sessions)
    {
        var path = ctx.Request.Path.Value ?? "";
        if (path.StartsWith("/health") ||
            (HttpMethods.IsPost(ctx.Request.Method) && path == "/api/v1/sessions"))
        {
            await _next(ctx);
            return;
        }

        if (!path.StartsWith("/api/v1"))
        {
            await _next(ctx);
            return;
        }

        string? token = null;
        var auth = ctx.Request.Headers.Authorization.ToString();
        if (auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            token = auth["Bearer ".Length..].Trim();

        SessionInfo? session = null;
        if (!string.IsNullOrEmpty(token))
            session = sessions.Validate(token, DateTime.UtcNow);

        if (session is null)
        {
            ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
            ctx.Response.ContentType = "application/problem+json";
            await ctx.Response.WriteAsJsonAsync(ApiError.Body("SESSION_EXPIRED", ctx.TraceIdentifier));
            return;
        }

        ctx.Items["smi.session"] = session;
        await _next(ctx);
    }
}

/// <summary>ProblemDetails helper with the spec-required extensions: code, traceId, optional callId.</summary>
public static class ApiError
{
    public static object Body(string code, string traceId, string? callId = null, string? detail = null) =>
        new Dictionary<string, object?>
        {
            ["type"] = $"about:blank",
            ["title"] = code,
            ["status"] = 0, // replaced below when written with a status
            ["code"] = code,
            ["traceId"] = traceId,
            ["callId"] = callId,
            ["detail"] = detail,
        };

    public static IResult Problem(HttpContext ctx, int status, string code, string? callId = null, string? detail = null)
    {
        var body = new Dictionary<string, object?>
        {
            ["type"] = "about:blank",
            ["title"] = code,
            ["status"] = status,
            ["code"] = code,
            ["traceId"] = ctx.TraceIdentifier,
            ["callId"] = callId,
        };
        if (detail is not null) body["detail"] = detail;
        return Results.Problem(new Microsoft.AspNetCore.Mvc.ProblemDetails
        {
            Status = status,
            Title = code,
            Type = "about:blank",
            Extensions = body.Where(kv => kv.Key is "code" or "traceId" or "callId" or "detail")
                             .ToDictionary(kv => kv.Key, kv => (object?)kv.Value?.ToString()),
        });
    }
}
