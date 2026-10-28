using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Smi.Control.Push;

/// <summary>
/// Push contract (spec section 9). Payload carries ONLY: schemaVersion, type, callId,
/// caller/callee extensions, deviceGeneration, expiresAt. No SIP secrets, session
/// tokens or private keys ever travel in a push. Receiving FCM/APNs is NOT proof of
/// delivery to the device (spec 4.3).
/// </summary>
public sealed record PushPayload(int SchemaVersion, string Type, string CallId,
    string CallerExtension, string CalleeExtension, int DeviceGeneration, DateTime ExpiresAtUtc)
{
    public string ToJson() => JsonSerializer.Serialize(new Dictionary<string, object?>
    {
        ["schemaVersion"] = SchemaVersion,
        ["type"] = Type,
        ["callId"] = CallId,
        ["callerExtension"] = CallerExtension,
        ["calleeExtension"] = CalleeExtension,
        ["deviceGeneration"] = DeviceGeneration.ToString(), // FCM data fields are strings
        ["expiresAt"] = ExpiresAtUtc.ToString("o"),
    });
}

public sealed record PushResult(bool Accepted, string? Status, string? Detail);

/// <summary>Dispatch is selected by the callee device platform. Missing credentials = explicit failure, never fake success.</summary>
public sealed class PushDispatch
{
    private readonly ApnsSender? _apns;
    private readonly FcmSender? _fcm;
    private readonly ILogger<PushDispatch> _log;

    public PushDispatch(SmiConfig cfg, ILogger<PushDispatch> log, ILogger<ApnsSender> apnsLog, ILogger<FcmSender> fcmLog, HttpClient http)
    {
        _log = log;
        try
        {
            if (!string.IsNullOrEmpty(cfg.ApnsP8Path) && File.Exists(cfg.ApnsP8Path) &&
                !string.IsNullOrEmpty(cfg.ApnsKeyId) && !string.IsNullOrEmpty(cfg.ApnsTeamId) &&
                !string.IsNullOrEmpty(cfg.ApnsBundleId))
                _apns = new ApnsSender(cfg, apnsLog, http);
            else
                _log.LogWarning("APNs not configured (employer input B2) — iOS push will report failure");
        }
        catch (Exception ex) { _log.LogError(ex, "APNs sender init failed"); }

        try
        {
            if (!string.IsNullOrEmpty(cfg.FcmServiceAccountPath) && File.Exists(cfg.FcmServiceAccountPath) &&
                !string.IsNullOrEmpty(cfg.FcmProjectId))
                _fcm = new FcmSender(cfg, fcmLog, http);
            else
                _log.LogWarning("FCM not configured (employer input B3) — Android push will report failure");
        }
        catch (Exception ex) { _log.LogError(ex, "FCM sender init failed"); }
    }

    public async Task<bool> SendIncomingCallAsync(Calls.CallRow call)
    {
        var payload = new PushPayload(1, "incoming_call", call.CallId,
            call.CallerExt, call.CalleeExt, call.CalleeDeviceGeneration, call.DeadlineUtc);
        // device/platform resolution is done by the endpoint layer via PushBinding; the
        // coordinator only knows the call — we send to BOTH providers' last-known tokens.
        // (A single active device per extension exists; provider chosen by its binding.)
        // v0.1: platform-specific routing is wired through SessionService bindings at API layer.
        var anyOk = false;
        if (_apns is not null)
        {
            var r = await _apns.SendToEnvironmentAsync(payload, call.CalleeExt);
            anyOk |= r.Accepted;
        }
        if (_fcm is not null)
        {
            var r = await _fcm.SendDataAsync(payload, call.CalleeExt);
            anyOk |= r.Accepted;
        }
        return anyOk;
    }

    public Task<PushResult> SendCancelDataAsync(Calls.CallRow call) =>
        _fcm?.SendDataAsync(new PushPayload(1, "cancel_call", call.CallId,
            call.CallerExt, call.CalleeExt, call.CalleeDeviceGeneration, call.DeadlineUtc), call.CalleeExt)
        ?? Task.FromResult(new PushResult(false, "not_configured", "FCM sender absent"));
}

/// <summary>
/// APNs token-based sender (spec 9.2): HTTP/2, JWT ES256 from the employer's .p8,
/// apns-push-type: voip, topic = bundle.voip, priority 10, expiration 0.
/// Token invalidation touches only the exact token that errored (no stale-response deletion).
/// </summary>
public sealed class ApnsSender
{
    private readonly SmiConfig _cfg;
    private readonly ILogger<ApnsSender> _log;
    private readonly HttpClient _http;
    private readonly ECDsa _key;
    private (string Jwt, DateTime IssuedUtc) _cachedJwt;

    private static readonly Dictionary<string, string> Hosts = new()
    {
        ["production"] = "https://api.push.apple.com",
        ["sandbox"] = "https://api.sandbox.push.apple.com",
    };

    public ApnsSender(SmiConfig cfg, ILogger<ApnsSender> log, HttpClient http)
    {
        _cfg = cfg; _log = log; _http = http;
        var pem = File.ReadAllText(cfg.ApnsP8Path!);
        var base64 = string.Concat(pem
            .Split('\n')
            .Where(l => !l.Contains("-----"))
            .Select(l => l.Trim()));
        _key = ECDsa.Create();
        _key.ImportPkcs8PrivateKey(Convert.FromBase64String(base64), out _);
        _http.DefaultRequestVersion = System.Net.HttpVersion.Version20;
        _http.DefaultVersionPolicy = HttpVersionPolicy.RequestVersionExact;
    }

    private string BuildJwt(DateTime nowUtc)
    {
        if (_cachedJwt.Jwt is not null && nowUtc - _cachedJwt.IssuedUtc < TimeSpan.FromMinutes(45))
            return _cachedJwt.Jwt;

        string B64Url(byte[] b) => Convert.ToBase64String(b).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var header = B64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "ES256", kid = _cfg.ApnsKeyId, typ = "JWT" }));
        var claims = B64Url(JsonSerializer.SerializeToUtf8Bytes(new { iss = _cfg.ApnsTeamId, iat = new DateTimeOffset(nowUtc).ToUnixTimeSeconds() }));
        var unsigned = $"{header}.{claims}";
        var sig = _key.SignData(Encoding.ASCII.GetBytes(unsigned), HashAlgorithmName.SHA256);
        // ES256 signature = r || s, each padded to 32 bytes
        var r = sig[..(sig.Length / 2)];
        var s = sig[(sig.Length / 2)..];
        var jwt = $"{unsigned}.{B64Url(r)}{B64Url(s)}";
        _cachedJwt = (jwt, nowUtc);
        return jwt;
    }

    /// <summary>Send to the active push binding of an extension. Resolve token via SessionService at API layer (v0.1: by extension).</summary>
    public async Task<PushResult> SendToEnvironmentAsync(PushPayload payload, string calleeExtension)
    {
        var host = Hosts.GetValueOrDefault(_cfg.ApnsEnvironment, Hosts["production"]);
        var topic = $"{_cfg.ApnsBundleId}.voip";
        // Token lookup by extension happens through the push-binding table; v0.1 wires it in PushDispatch.
        _log.LogWarning("APNs send for ext {Ext}: token resolution requires device binding (wired at API layer)", calleeExtension);
        return await Task.FromResult(new PushResult(false, "token_resolution_pending", "iOS push token binding wired in P3"));
    }

    public async Task<PushResult> SendAsync(string deviceToken, PushPayload payload)
    {
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Post, $"{Hosts.GetValueOrDefault(_cfg.ApnsEnvironment, Hosts["production"])}/3/device/{deviceToken}");
            req.Headers.TryAddWithoutValidation("apns-push-type", "voip");
            req.Headers.TryAddWithoutValidation("apns-topic", $"{_cfg.ApnsBundleId}.voip");
            req.Headers.TryAddWithoutValidation("apns-priority", "10");
            req.Headers.TryAddWithoutValidation("apns-expiration", "0");
            req.Headers.TryAddWithoutValidation("apns-id", Guid.NewGuid().ToString("D"));
            req.Headers.TryAddWithoutValidation("authorization", $"bearer {BuildJwt(DateTime.UtcNow)}");
            req.Content = new StringContent(payload.ToJson(), Encoding.UTF8, "application/json");

            using var res = await _http.SendAsync(req);
            var apnsId = res.Headers.TryGetValues("apns-id", out var ids) ? ids.FirstOrDefault() : null;
            if ((int)res.StatusCode == 200) return new PushResult(true, "200", apnsId);
            if ((int)res.StatusCode == 410 || (int)res.StatusCode == 400)
                return new PushResult(false, ((int)res.StatusCode).ToString(), apnsId); // token invalid → deactivate THIS token only
            return new PushResult(false, ((int)res.StatusCode).ToString(), apnsId);     // 429/5xx → short retry within deadline
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "APNs send failed");
            return new PushResult(false, "exception", ex.GetType().Name);
        }
    }
}

/// <summary>FCM HTTP v1 sender (spec 9.4): high-priority data message with TTL = remaining setup time.</summary>
public sealed class FcmSender
{
    private readonly SmiConfig _cfg;
    private readonly ILogger<FcmSender> _log;
    private readonly HttpClient _http;
    private (string AccessToken, DateTime ExpiresUtc)? _cachedToken;

    public FcmSender(SmiConfig cfg, ILogger<FcmSender> log, HttpClient http)
    { _cfg = cfg; _log = log; _http = http; }

    private sealed record ServiceAccount(string ClientEmail, string PrivateKeyPem)
    {
        public static ServiceAccount Load(string path)
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(path));
            var root = doc.RootElement;
            return new ServiceAccount(
                root.GetProperty("client_email").GetString()!,
                root.GetProperty("private_key").GetString()!);
        }
    }

    private async Task<string?> GetAccessTokenAsync()
    {
        if (_cachedToken is { } t && DateTime.UtcNow < t.ExpiresUtc) return t.AccessToken;
        try
        {
            var sa = ServiceAccount.Load(_cfg.FcmServiceAccountPath!);
            using var key = ECDsa.Create();
            var pemBody = string.Concat(sa.PrivateKeyPem.Split('\n').Where(l => !l.Contains("-----")).Select(l => l.Trim()));
            key.ImportPkcs8PrivateKey(Convert.FromBase64String(pemBody), out _);

            string B64Url(byte[] b) => Convert.ToBase64String(b).TrimEnd('=').Replace('+', '-').Replace('/', '_');
            var now = DateTime.UtcNow;
            var header = B64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "ES256", typ = "JWT" }));
            var claims = B64Url(JsonSerializer.SerializeToUtf8Bytes(new
            {
                iss = sa.ClientEmail,
                scope = "https://www.googleapis.com/auth/firebase.messaging",
                aud = "https://oauth2.googleapis.com/token",
                iat = new DateTimeOffset(now).ToUnixTimeSeconds(),
                exp = new DateTimeOffset(now.AddMinutes(55)).ToUnixTimeSeconds(),
            }));
            var unsigned = $"{header}.{claims}";
            var sig = key.SignData(Encoding.ASCII.GetBytes(unsigned), HashAlgorithmName.SHA256);
            var assertion = $"{unsigned}.{B64Url(sig[..(sig.Length / 2)])}{B64Url(sig[(sig.Length / 2)..])}";

            using var req = new HttpRequestMessage(HttpMethod.Post, "https://oauth2.googleapis.com/token")
            {
                Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ["assertion"] = assertion,
                }),
            };
            using var res = await _http.SendAsync(req);
            if ((int)res.StatusCode != 200) { _log.LogError("FCM token exchange failed: {Status}", (int)res.StatusCode); return null; }
            using var doc = JsonDocument.Parse(await res.Content.ReadAsStringAsync());
            var accessToken = doc.RootElement.GetProperty("access_token").GetString()!;
            _cachedToken = (accessToken, now.AddMinutes(50));
            return accessToken;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "FCM auth failed");
            return null;
        }
    }

    public async Task<PushResult> SendDataAsync(PushPayload payload, string calleeExtension)
    {
        var token = await GetAccessTokenAsync();
        if (token is null) return new PushResult(false, "auth_failed", null);
        // Device token + routing to the active Android binding is resolved at API layer (P3 wiring).
        _log.LogWarning("FCM send for ext {Ext}: token resolution requires device binding (wired at API layer)", calleeExtension);
        return await Task.FromResult(new PushResult(false, "token_resolution_pending", "Android push token binding wired in P3"));
    }

    public async Task<PushResult> SendToDeviceAsync(string deviceToken, PushPayload payload, int ttlSeconds)
    {
        try
        {
            var token = await GetAccessTokenAsync();
            if (token is null) return new PushResult(false, "auth_failed", null);

            var body = JsonSerializer.Serialize(new Dictionary<string, object?>
            {
                ["message"] = new Dictionary<string, object?>
                {
                    ["token"] = deviceToken,
                    ["android"] = new Dictionary<string, object?>
                    {
                        ["priority"] = "HIGH",
                        ["ttl"] = $"{Math.Max(1, ttlSeconds)}s",
                        ["data"] = JsonDocument.Parse(payload.ToJson()).RootElement,
                    },
                },
            });
            using var req = new HttpRequestMessage(HttpMethod.Post,
                $"https://fcm.googleapis.com/v1/projects/{_cfg.FcmProjectId}/messages:send");
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
            req.Content = new StringContent(body, Encoding.UTF8, "application/json");
            using var res = await _http.SendAsync(req);
            return new PushResult((int)res.StatusCode == 200, ((int)res.StatusCode).ToString(), null);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "FCM send failed");
            return new PushResult(false, "exception", ex.GetType().Name);
        }
    }
}
