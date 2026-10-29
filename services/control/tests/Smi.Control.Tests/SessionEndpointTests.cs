using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Smi.Control;
using Smi.Control.Calls;
using Smi.Control.Database;
using Xunit;

namespace Smi.Control.Tests;

/// <summary>
/// Real HTTP pipeline via WebApplicationFactory (spec 15.1 integration level):
/// auth, device binding, error shapes (ProblemDetails with code/traceId), party authorization.
/// AMI is intentionally NOT configured here — the service must boot and serve sessions
/// with AMI degraded (fail-closed semantics for calls, login still works).
/// </summary>
public class SessionEndpointTests : IClassFixture<ControlApiFixture>
{
    private readonly ControlApiFixture _fx;
    public SessionEndpointTests(ControlApiFixture fx) { _fx = fx; }

    private static HttpContent Json(object o) => new StringContent(JsonSerializer.Serialize(o), System.Text.Encoding.UTF8, "application/json");

    private static (HttpResponseMessage Res, JsonElement Body) AsJson(HttpResponseMessage res)
    {
        var text = res.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        var body = string.IsNullOrWhiteSpace(text) ? default : JsonDocument.Parse(text).RootElement.Clone();
        return (res, body);
    }

    [Fact]
    public async Task Login_WrongPassword_AndUnknownExt_GiveIdenticalGenericError()
    {
        var client = _fx.Factory.CreateClient();
        var (r1, b1) = AsJson(await client.PostAsync("/api/v1/sessions", Json(new
        {
            extension = "111", password = "definitely-wrong", installationId = Guid.NewGuid().ToString(), platform = "android",
        })));
        var (r2, b2) = AsJson(await client.PostAsync("/api/v1/sessions", Json(new
        {
            extension = "199", password = "whatever", installationId = Guid.NewGuid().ToString(), platform = "android",
        })));
        Assert.Equal(HttpStatusCode.Unauthorized, r1.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, r2.StatusCode);
        Assert.Equal(b1.GetProperty("code").GetString(), b2.GetProperty("code").GetString()); // no account disclosure
        Assert.Equal("INVALID_CREDENTIALS", b1.GetProperty("code").GetString());
        Assert.True(b1.TryGetProperty("traceId", out _));
    }

    [Fact]
    public async Task Login_Ok_ReturnsRequiredContractFields()
    {
        var (res, body) = await _fx.LoginRawAsync("111", ControlApiFixture.DefaultPassword);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.Equal("111", body.GetProperty("extension").GetString());
        Assert.Equal("wss://test.local/ws", body.GetProperty("wssUrl").GetString());
        Assert.Equal(40, body.GetProperty("setupTimeoutSeconds").GetInt32());
        Assert.True(body.GetProperty("accessToken").GetString()!.Length >= 40);
        Assert.Equal("sip:111@test.local", body.GetProperty("sipUri").GetString());
        Assert.True(body.TryGetProperty("idleExpiresAt", out var expiry));
        Assert.True(DateTime.TryParse(expiry.GetString(), out _));
        Assert.False(body.TryGetProperty("idleExpiresAtUtc", out _));
        Assert.Equal("sipsecret", body.GetProperty("sipPassword").GetString());
        Assert.NotEqual(ControlApiFixture.DefaultPassword, body.GetProperty("sipPassword").GetString());
        Assert.Contains("no-store", res.Headers.CacheControl!.ToString());
    }

    [Fact]
    public async Task SecondDevice_IsRejected409_AfterPasswordCheck()
    {
        var (first, _) = await _fx.LoginRawAsync("112", ControlApiFixture.DefaultPassword);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);

        var (second, b2) = await _fx.LoginRawAsync("112", ControlApiFixture.DefaultPassword, installationId: Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        Assert.Equal("DEVICE_ALREADY_BOUND", b2.GetProperty("code").GetString());
    }

    [Fact]
    public async Task Me_RequiresBearer_AndReturnsSetup()
    {
        var client = _fx.Factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/me")).StatusCode);

        var (_, loginBody) = await _fx.LoginRawAsync("111", ControlApiFixture.DefaultPassword);
        client.DefaultRequestHeaders.Authorization = new("Bearer", loginBody.GetProperty("accessToken").GetString());
        var (me, m) = AsJson(await client.GetAsync("/api/v1/me"));
        Assert.Equal(HttpStatusCode.OK, me.StatusCode);
        Assert.Equal("ulaw", m.GetProperty("codec").GetString());
        Assert.Equal("test.local", m.GetProperty("sipUri").GetString()!.Split('@')[1]);
    }

    [Fact]
    public async Task CallEndpoints_EnforcePartyAuthorization_T40()
    {
        _fx.EndAllCalls();
        // caller 111 → callee 112; stranger 113 must see nothing (404)
        var caller = await _fx.LoginAsync("111", ControlApiFixture.DefaultPassword);
        var callee = await _fx.LoginAsync("112", ControlApiFixture.DefaultPassword);
        var stranger = await _fx.LoginAsync("113", ControlApiFixture.DefaultPassword);

        var callId = _fx.CreateCallDirect("111", "112");

        var hCaller = _fx.Factory.CreateClient();
        hCaller.DefaultRequestHeaders.Authorization = new("Bearer", caller.Token);
        var hCallee = _fx.Factory.CreateClient();
        hCallee.DefaultRequestHeaders.Authorization = new("Bearer", callee.Token);
        var hStranger = _fx.Factory.CreateClient();
        hStranger.DefaultRequestHeaders.Authorization = new("Bearer", stranger.Token);

        foreach (var route in new[] { $"/api/v1/calls/{callId}", "/api/v1/calls/current" })
        {
            var (response, value) = AsJson(await hCallee.GetAsync(route));
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            AssertCallContract(value, callId);
        }
        Assert.Equal(HttpStatusCode.NotFound, (await hStranger.GetAsync($"/api/v1/calls/{callId}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await hCaller.PostAsync($"/api/v1/calls/{callId}/ready", Json(new { deviceGeneration = 1 }))).StatusCode);

        var (ok, body) = AsJson(await hCallee.PostAsync($"/api/v1/calls/{callId}/accept", Json(new { })));
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        Assert.Equal("Connecting", body.GetProperty("state").GetString());
        AssertCallContract(body, callId);

        // Ended is terminal: another accept after decline stays terminal (T41)
        await hCallee.PostAsync($"/api/v1/calls/{callId}/decline", Json(new { }));
        var (again, ab) = AsJson(await hCallee.GetAsync($"/api/v1/calls/{callId}"));
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal("Ended", ab.GetProperty("state").GetString());
        Assert.Equal("Declined", ab.GetProperty("endReason").GetString());

        // slots were freed: a fresh call can be admitted (T10 invariant)
        var secondCall = _fx.CreateCallDirect("111", "112");
        Assert.NotEqual(callId, secondCall);
        _fx.EndAllCalls(); // fixture hygiene: leave no live slots for sibling tests
    }

    private static void AssertCallContract(JsonElement body, string callId)
    {
        Assert.Equal(callId, body.GetProperty("callId").GetString());
        Assert.Equal("111", body.GetProperty("caller").GetString());
        Assert.Equal("112", body.GetProperty("callee").GetString());
        Assert.True(body.GetProperty("deviceGeneration").GetInt32() >= 1);
        foreach (var field in new[] { "createdAt", "expiresAt", "serverTime" })
            Assert.True(DateTime.TryParse(body.GetProperty(field).GetString(), out _));
        foreach (var field in new[] { "acceptedAt", "connectedAt", "endedAt", "endReason" })
            Assert.True(body.TryGetProperty(field, out _));
        foreach (var field in new[] { "callerExt", "calleeExt", "deadlineUtc", "channelName", "pbxInstanceId", "pbxUniqueId" })
            Assert.False(body.TryGetProperty(field, out _));
    }

    [Fact]
    public async Task Ready_WithWrongDeviceGeneration_GivesStaleDevice_T05()
    {
        _fx.EndAllCalls();
        var callee = await _fx.LoginAsync("112", ControlApiFixture.DefaultPassword);
        var callId = _fx.CreateCallDirect("111", "112");
        var hCallee = _fx.Factory.CreateClient();
        hCallee.DefaultRequestHeaders.Authorization = new("Bearer", callee.Token);

        var (res, body) = AsJson(await hCallee.PostAsync($"/api/v1/calls/{callId}/ready", Json(new { deviceGeneration = 99 })));
        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
        Assert.Equal("STALE_DEVICE", body.GetProperty("code").GetString());
    }
}

public sealed class ControlApiFixture : IDisposable
{
    public const string DefaultPassword = "test-password-123";
    private const string Caller = "111", Callee = "112", Stranger = "113";

    public string DbPath { get; }
    public WebApplicationFactory<Program> Factory { get; }
    private readonly Db _db;

    public ControlApiFixture()
    {
        DbPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"smi-api-{Guid.NewGuid():N}.db");
        Environment.SetEnvironmentVariable("SMI_DB_PATH", DbPath);
        Environment.SetEnvironmentVariable("SMI_DOMAIN", "test.local");
        Factory = new WebApplicationFactory<Program>();
        _db = Factory.Services.GetRequiredService<Db>();
        SeedExtension(Caller);
        SeedExtension(Callee, seedActiveDevice: true);
        SeedExtension(Stranger);
    }

    private static HttpContent Json(object o) =>
        new StringContent(JsonSerializer.Serialize(o), System.Text.Encoding.UTF8, "application/json");

    public void EndAllCalls()
    {
        var store = Factory.Services.GetRequiredService<CallStore>();
        foreach (var call in store.ListActive().ToList())
            store.EndWithReason(call.CallId, EndReason.ServerRestart, DateTime.UtcNow);
    }

    public async Task<(HttpResponseMessage Res, JsonElement Body)> LoginRawAsync(string ext, string password,
        string? installationId = null)
    {
        installationId ??= DeterministicId(ext);
        var client = Factory.CreateClient();
        var res = await client.PostAsync("/api/v1/sessions", Json(new
        {
            extension = ext, password, installationId, platform = "android",
        }));
        var text = await res.Content.ReadAsStringAsync();
        var body = string.IsNullOrWhiteSpace(text)
            ? default
            : JsonDocument.Parse(text).RootElement.Clone();
        return (res, body);
    }

    public async Task<(string Token, string InstallationId)> LoginAsync(string ext, string password,
        string? installationId = null)
    {
        var (res, body) = await LoginRawAsync(ext, password, installationId);
        res.EnsureSuccessStatusCode();
        return (body.GetProperty("accessToken").GetString()!, installationId!);
    }

    /// installationId must be a CSPRNG UUID per spec 4.1 — tests use stable v4-shaped GUIDs.
    public static string DeterministicId(string ext) => $"00000000-0000-4000-8000-{int.Parse(ext):D12}";

    /// <summary>Directly simulate a PBX admission (the real path arrives via AMI events).</summary>
    public string CreateCallDirect(string callerExt, string calleeExt)
    {
        var store = Factory.Services.GetRequiredService<CallStore>();
        var outcome = store.Admit(callerExt, calleeExt, Guid.NewGuid().ToString(), "test-instance",
            $"pbx-{Guid.NewGuid():N}", $"PJSIP/{callerExt}-{Guid.NewGuid():N}", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.Created, outcome.Result);
        return outcome.Call!.CallId;
    }

    private void SeedExtension(string ext) => SeedExtension(ext, seedActiveDevice: false);

    private void SeedExtension(string ext, bool seedActiveDevice)
    {
        var (hash, salt, iters) = Crypto.HashPassword(DefaultPassword);
        using var c = _db.Open();
        Db.Exec(c, """
            INSERT OR IGNORE INTO Extensions(Extension,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,SipSecret,ConfigurationGeneration,CreatedAtUtc,UpdatedAtUtc)
            VALUES(@e,1,@h,@s,@it,'sipsecret',1,@n,@n)
            """, ("@e", ext), ("@h", hash), ("@s", salt), ("@it", iters), ("@n", DateTime.UtcNow.ToString("o")));
        if (seedActiveDevice)
        {
            // the callee must have an active device for admission to succeed; its
            // installationId matches the default login id so test logins rotate it
            Db.Exec(c, """
                INSERT OR IGNORE INTO Devices(InstallationId,Extension,Platform,DeviceGeneration,Active,LastSeenAtUtc)
                VALUES(@i,@e,'android',1,1,@n)
                """, ("@i", DeterministicId(ext)), ("@e", ext), ("@n", DateTime.UtcNow.ToString("o")));
        }
    }

    public void Dispose()
    {
        Factory.Dispose();
        try
        {
            File.Delete(DbPath); File.Delete(DbPath + "-wal"); File.Delete(DbPath + "-shm");
        }
        catch { }
    }
}
