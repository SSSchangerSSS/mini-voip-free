using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Smi.Control;
using Smi.Control.Ami;
using Smi.Control.Auth;
using Smi.Control.Calls;
using Smi.Control.Database;
using Smi.Control.Health;
using Smi.Control.Provisioning;
using Smi.Control.Push;

// ─── CLI mode: extensions/device management is a mode of the Control program (spec 11.2) ───
if (args.Length > 0 && args[0] is "extensions" or "device")
{
    var cfgCli = SmiConfig.FromEnvironment();
    var dbCli = new Db(cfgCli);
    dbCli.Migrate();
    var amiCli = new AmiClient(cfgCli, NullLogger<AmiClient>.Instance);
    var callsCli = new CallStore(dbCli, cfgCli);
    return await ExtensionsCli.RunAsync(args, cfgCli, dbCli, amiCli, callsCli);
}

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddSimpleConsole(o => { o.SingleLine = true; o.TimestampFormat = "yyyy-MM-ddTHH:mm:ssZ "; });

// Wire contract (spec 7.3): enums are STRINGS ("state": "Pending"), camelCase fields.
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.Converters.Add(new System.Text.Json.Serialization.JsonStringEnumConverter());
});

var cfg = SmiConfig.FromEnvironment();
builder.Services.AddSingleton(cfg);
builder.Services.AddSingleton<Db>(_ => { var d = new Db(cfg); d.Migrate(); return d; });
builder.Services.AddSingleton<SessionService>();
builder.Services.AddSingleton<CallStore>();
builder.Services.AddSingleton<Readiness>();
builder.Services.AddSingleton<AmiClient>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<AmiClient>());
builder.Services.AddSingleton<AmiCallCoordinator>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<AmiCallCoordinator>());
builder.Services.AddSingleton<PushDispatch>();
builder.Services.AddHttpClient();

var app = builder.Build();
var readiness = app.Services.GetRequiredService<Readiness>();
readiness.MigrationsApplied = true;

// readiness reflects AMI state (spec 14.2)
var amiRef = app.Services.GetRequiredService<AmiClient>();
_ = Task.Run(async () =>
{
    while (true)
    {
        readiness.AmiConnected = amiRef.ConnectedAndLoggedIn;
        readiness.AmiReconciled = amiRef.Reconciled;
        await Task.Delay(500);
    }
});

// structured log + generic 500 without leaking internals (spec 14.2, 11.1)
app.Use(async (ctx, next) =>
{
    try { await next(ctx); }
    catch (InvalidTransitionException) { ctx.Response.StatusCode = 409; await ctx.Response.WriteAsJsonAsync(ApiError.Body("INVALID_TRANSITION", ctx.TraceIdentifier)); }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "unhandled error on {Path}", ctx.Request.Path);
        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "application/problem+json";
        await ctx.Response.WriteAsJsonAsync(ApiError.Body("INTERNAL", ctx.TraceIdentifier));
    }
});
app.UseMiddleware<AuthMiddleware>();

// ─── Health (public, no internal detail) ───
app.MapGet("/health/live", () => Results.Ok(new { status = "live" }));
app.MapGet("/health/ready", () =>
{
    var (ready, summary) = readiness.Evaluate();
    return ready ? Results.Ok(summary) : Results.Json(summary, statusCode: 503);
});

// ─── Sessions ───
app.MapPost("/api/v1/sessions", async (HttpContext ctx, JsonElement body, SessionService sessions) =>
{
    string Get(string k) => body.ValueKind == JsonValueKind.Object && body.TryGetProperty(k, out var v) ? v.GetString() ?? "" : "";
    var extRaw = Get("extension");
    var password = Get("password");
    var installationId = Get("installationId");
    var platform = Get("platform");

    var ext = DigitNormalizer.NormalizeInternal(extRaw);
    if (ext is null || password.Length == 0 || !Guid.TryParse(installationId, out _))
        return ApiError.Problem(ctx, 400, "INVALID_INPUT");

    var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    if (LoginThrottle.IsBlocked(ip, ext))
        return ApiError.Problem(ctx, 429, "RATE_LIMITED");

    var (result, failure) = sessions.Login(ext, password, installationId, platform, DateTime.UtcNow);
    if (failure == LoginFailure.DeviceAlreadyBound)
        return ApiError.Problem(ctx, 409, "DEVICE_ALREADY_BOUND");
    if (failure is not null)
    {
        LoginThrottle.RecordFailure(ip, ext);   // generic failure — never disclose account existence
        return ApiError.Problem(ctx, 401, "INVALID_CREDENTIALS");
    }
    LoginThrottle.Reset(ip, ext);
    ctx.Response.Headers.CacheControl = "no-store";
    return Results.Ok(result);
});

app.MapDelete("/api/v1/sessions/current", async (HttpContext ctx, SessionService sessions, CallStore calls, AmiCallCoordinator coordinator) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    // end any live call first, then revoke + unbind push (spec 7.4)
    var call = calls.GetCurrentFor(s.Extension);
    if (call is not null && call.State != CallState.Ended)
    {
        calls.End(call.CallId, s.Extension, EndReason.Completed, DateTime.UtcNow);
        var fresh = calls.GetById(call.CallId);
        if (fresh is not null) await coordinator.EndViaPbxAsync(fresh, 16);
    }
    sessions.Revoke(s.TokenHash, DateTime.UtcNow);
    sessions.UnbindPush(s.InstallationId, DateTime.UtcNow);
    return Results.NoContent();
});

// ─── Me / device push binding ───
app.MapGet("/api/v1/me", (HttpContext ctx, SmiConfig c) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    return Results.Ok(new
    {
        extension = s.Extension,
        deviceGeneration = s.DeviceGeneration,
        codec = "ulaw",
        setupTimeoutSeconds = c.SetupTimeoutSeconds,
        sipUri = $"sip:{s.Extension}@{c.SipRealm}",
        sipUsername = s.Extension,
        wssUrl = c.WssUrl,
    });
});

app.MapPut("/api/v1/devices/current/push", async (HttpContext ctx, JsonElement body, SessionService sessions, CallStore calls, AmiCallCoordinator coordinator) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    string Get(string k) => body.ValueKind == JsonValueKind.Object && body.TryGetProperty(k, out var v) ? v.GetString() ?? "" : "";
    var provider = Get("provider");
    var token = Get("token");
    var environment = Get("environment");
    if (provider is not ("apns" or "fcm")) return ApiError.Problem(ctx, 400, "INVALID_INPUT");
    if (environment is not ("production" or "sandbox")) return ApiError.Problem(ctx, 400, "INVALID_INPUT");

    if (token.Length == 0)
    {
        sessions.UnbindPush(s.InstallationId, DateTime.UtcNow); // explicit unregister
        return Results.NoContent();
    }
    if (token.Length > 4096) return ApiError.Problem(ctx, 400, "INVALID_INPUT");
    var ok = sessions.SetPushBinding(s.InstallationId, provider, token, environment, DateTime.UtcNow);
    return ok ? Results.NoContent() : ApiError.Problem(ctx, 409, "STALE_DEVICE");
});

// ─── ICE servers (only when TURN profile is enabled, spec 2.4/7.2) ───
app.MapGet("/api/v1/ice-servers", (HttpContext ctx, SmiConfig c) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    if (!c.TurnEnabled) return ApiError.Problem(ctx, 503, "TURN_DISABLED");
    // TURN credentials are issued by an authenticated endpoint with server-side secret (spec 2.4);
    // actual coturn wiring happens only if the network gate proves the need.
    return Results.Ok(Array.Empty<object>());
});

// ─── Calls ───
app.MapGet("/api/v1/calls/current", (HttpContext ctx, CallStore calls, string? attemptId) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    CallRow? call = attemptId is not null
        ? calls.GetByAttemptIdFor(s.Extension, attemptId)   // same attempt allowed even if terminal (retention)
        : calls.GetCurrentFor(s.Extension);
    return call is null ? Results.Json<object?>(null) : Results.Ok(CallStateResponse.From(call));
});

app.MapGet("/api/v1/calls/{callId}", (HttpContext ctx, string callId, CallStore calls) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    var call = calls.GetById(callId);
    if (call is null || !call.IsParty(s.Extension)) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    return Results.Ok(CallStateResponse.From(call));
});

app.MapPost("/api/v1/calls/{callId}/ready", async (HttpContext ctx, string callId, JsonElement body, CallStore calls, AmiCallCoordinator coordinator, SmiConfig c) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    var pre = calls.GetById(callId);
    if (pre is null || !pre.IsParty(s.Extension)) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (pre.CalleeExt != s.Extension) return ApiError.Problem(ctx, 403, "NOT_CALLEE", callId);
    var gen = body.ValueKind == JsonValueKind.Object && body.TryGetProperty("deviceGeneration", out var g) && g.TryGetInt32(out var gi) ? gi : -1;
    var (call, error) = calls.MarkDeviceReady(callId, s.Extension, gen, DateTime.UtcNow);
    if (call is null) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (error == "STALE_DEVICE") return ApiError.Problem(ctx, 409, "STALE_DEVICE", call.CallId);
    if (error == "CALL_EXPIRED") return ApiError.Problem(ctx, 410, "CALL_EXPIRED", call.CallId);
    if (error == "CALL_ENDED") return ApiError.Problem(ctx, 410, "CALL_ENDED", call.CallId);
    // first ready for a live call gates the dial; repeated ready must not create a second call (spec 5.2)
    if (error is null && call.State == CallState.Pending && call.DeviceReadyAtUtc is not null)
        await coordinator.AllowDialAsync(call);
    return Results.Ok(CallStateResponse.From(calls.GetById(callId)));
});

app.MapPost("/api/v1/calls/{callId}/accept", (HttpContext ctx, string callId, CallStore calls) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    var pre = calls.GetById(callId);
    if (pre is null || !pre.IsParty(s.Extension)) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (pre.CalleeExt != s.Extension) return ApiError.Problem(ctx, 403, "NOT_CALLEE", callId);
    var (call, error) = calls.Accept(callId, s.Extension, DateTime.UtcNow); // intent only — SIP answer happens in the app
    if (call is null) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (error == "CALL_EXPIRED") return ApiError.Problem(ctx, 410, "CALL_EXPIRED", call.CallId);
    if (error == "CALL_ENDED") return ApiError.Problem(ctx, 410, "CALL_ENDED", call.CallId);
    if (error == "INVALID_TRANSITION") return ApiError.Problem(ctx, 409, "INVALID_TRANSITION", call.CallId);
    return Results.Ok(CallStateResponse.From(call));
});

app.MapPost("/api/v1/calls/{callId}/decline", async (HttpContext ctx, string callId, CallStore calls, AmiCallCoordinator coordinator) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    var pre = calls.GetById(callId);
    if (pre is null || !pre.IsParty(s.Extension)) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (pre.CalleeExt != s.Extension) return ApiError.Problem(ctx, 403, "NOT_CALLEE", callId);
    var (call, error) = calls.Decline(callId, s.Extension, DateTime.UtcNow);
    if (call is null) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (error == "INVALID_TRANSITION") return ApiError.Problem(ctx, 409, "INVALID_TRANSITION", call.CallId);
    if (error is null)
        await coordinator.EndViaPbxAsync(call, 21); // reject before/around INVITE — server-terminated
    return Results.Ok(CallStateResponse.From(calls.GetById(callId)));
});

app.MapPost("/api/v1/calls/{callId}/end", async (HttpContext ctx, string callId, CallStore calls, AmiCallCoordinator coordinator) =>
{
    if (ctx.Items["smi.session"] is not SessionInfo s) return ApiError.Problem(ctx, 401, "SESSION_EXPIRED");
    var (call, error) = calls.End(callId, s.Extension, EndReason.Completed, DateTime.UtcNow);
    if (call is null) return ApiError.Problem(ctx, 404, "CALL_NOT_FOUND");
    if (error is not null && error != "CALL_ENDED") return ApiError.Problem(ctx, 409, error, call.CallId);
    // API end is the coordination/backstop path; the SIP CANCEL/BYE path is primary (spec 5.2 step 16).
    // 202 = accepted for PBX determination.
    var fresh = calls.GetById(callId);
    if (error is null && fresh is not null) await coordinator.EndViaPbxAsync(fresh, 16);
    return Results.Accepted($"/api/v1/calls/{callId}", CallStateResponse.From(fresh));
});

app.Run();
return 0; // all top-level paths must return (CLI branch above returns an int)

/// <summary>Exposes Program for WebApplicationFactory-based integration tests.</summary>
public partial class Program { }
