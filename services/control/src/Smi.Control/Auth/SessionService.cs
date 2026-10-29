using System.Text.Json;
using System.Text.Json.Serialization;
using Smi.Control.Database;

namespace Smi.Control.Auth;

public sealed record LoginRequest(string Extension, string Password, string InstallationId, string Platform);
public sealed record LoginResult(string AccessToken,
    [property: JsonPropertyName("idleExpiresAt")] DateTime IdleExpiresAtUtc, string Extension,
    int DeviceGeneration, string SipUri, string SipUsername, string SipPassword,
    string WssUrl, int SetupTimeoutSeconds, DateTime ServerTime)
{
    public override string ToString() => $"LoginResult(extension={Extension}, credentials=REDACTED)";
}
public sealed record SessionInfo(string TokenHash, string InstallationId, string Extension,
    int DeviceGeneration, DateTime IdleExpiresAtUtc);

public enum LoginFailure { InvalidCredentials, DeviceAlreadyBound, RateLimited, InvalidInput, UnknownInternal }

/// <summary>
/// Sessions + device binding (spec 7.1, 7.4, 11.x).
/// Token is random 256-bit; only its SHA-256 is stored. Login never discloses whether
/// an extension exists. A second device (different installationId) on an active binding
/// gets 409 DEVICE_ALREADY_BOUND — takeover is CLI-only.
/// </summary>
public sealed class SessionService
{
    private readonly Db _db;
    private readonly SmiConfig _cfg;

    public SessionService(Db db, SmiConfig cfg) { _db = db; _cfg = cfg; }

    public (LoginResult? Result, LoginFailure? Failure) Login(string extension, string password,
        string installationId, string platform, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);

        (string Ext, bool Enabled, string Hash, string Salt, int Iterations, string SipPassword)? ext = null;
        using (var r = Db.Query(c, "SELECT Extension,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,SipSecret FROM Extensions WHERE Extension=@e", ("@e", extension)))
        {
            if (r.Read()) ext = (r.GetString(0), r.GetInt64(1) == 1, r.GetString(2), r.GetString(3), (int)r.GetInt64(4), r.GetString(5));
        }

        if (ext is null || !ext.Value.Enabled || !Crypto.VerifyPassword(password, ext.Value.Hash, ext.Value.Salt, ext.Value.Iterations))
        {
            tx.Rollback();
            return (null, LoginFailure.InvalidCredentials);
        }

        // device binding — same installationId rotates the session; different one is rejected
        var activeDevice = Db.Scalar(c, "SELECT InstallationId FROM Devices WHERE Extension=@e AND Active=1", ("@e", extension)) as string;
        string deviceId;
        int generation;
        if (activeDevice is null)
        {
            deviceId = installationId;
            generation = 1;
            Db.Exec(c, """
                INSERT INTO Devices(InstallationId,Extension,Platform,DeviceGeneration,Active,LastSeenAtUtc)
                VALUES(@i,@e,@p,1,1,@n)
                """, ("@i", deviceId), ("@e", extension), ("@p", SanitizePlatform(platform)), ("@n", nowUtc.ToString("o")));
        }
        else if (activeDevice == installationId)
        {
            deviceId = activeDevice;
            generation = (int)(Db.ScalarLong(c, "SELECT DeviceGeneration FROM Devices WHERE InstallationId=@i", ("@i", deviceId)) ?? 1);
            Db.Exec(c, "UPDATE Devices SET LastSeenAtUtc=@n, Platform=@p WHERE InstallationId=@i",
                ("@n", nowUtc.ToString("o")), ("@p", SanitizePlatform(platform)), ("@i", deviceId));
        }
        else
        {
            tx.Rollback();
            return (null, LoginFailure.DeviceAlreadyBound);
        }

        var token = Crypto.NewAccessToken();
        var tokenHash = Crypto.TokenHash(token);
        var idleExpiry = nowUtc.AddDays(_cfg.SessionIdleDays);
        Db.Exec(c, "DELETE FROM Sessions WHERE InstallationId=@i", ("@i", deviceId)); // one live session per device
        Db.Exec(c, """
            INSERT INTO Sessions(TokenHash,InstallationId,Extension,CreatedAtUtc,IdleExpiresAtUtc)
            VALUES(@t,@i,@e,@c,@x)
            """, ("@t", tokenHash), ("@i", deviceId), ("@e", extension), ("@c", nowUtc.ToString("o")), ("@x", idleExpiry.ToString("o")));

        tx.Commit();
        return (new LoginResult(token, idleExpiry, extension, generation,
            $"sip:{extension}@{_cfg.SipRealm}", extension, ext.Value.SipPassword, _cfg.WssUrl, _cfg.SetupTimeoutSeconds, nowUtc), null);
    }

    public SessionInfo? Validate(string token, DateTime nowUtc)
    {
        var hash = Crypto.TokenHash(token);
        using var c = _db.Open();
        using var r = Db.Query(c, """
            SELECT s.TokenHash, s.InstallationId, s.Extension, s.IdleExpiresAtUtc, s.RevokedAtUtc, d.DeviceGeneration
            FROM Sessions s JOIN Devices d ON d.InstallationId = s.InstallationId
            WHERE s.TokenHash=@t
            """, ("@t", hash));
        if (!r.Read()) return null;
        if (!r.IsDBNull(4)) return null;                                  // revoked
        var expiry = DateTime.Parse(r.GetString(3));
        if (nowUtc > expiry) return null;                                  // idle-expired
        // renew idle window when less than half remains (spec 4.2: valid use extends it)
        if (expiry - nowUtc < TimeSpan.FromDays(_cfg.SessionIdleDays / 2.0))
        {
            var newExpiry = nowUtc.AddDays(_cfg.SessionIdleDays);
            Db.Exec(c, "UPDATE Sessions SET IdleExpiresAtUtc=@x WHERE TokenHash=@t", ("@x", newExpiry.ToString("o")), ("@t", hash));
            expiry = newExpiry;
        }
        return new SessionInfo(hash, r.GetString(1), r.GetString(2), (int)r.GetInt64(5), expiry);
    }

    public bool Revoke(string tokenHash, DateTime nowUtc)
    {
        using var c = _db.Open();
        return Db.Exec(c, "UPDATE Sessions SET RevokedAtUtc=@n WHERE TokenHash=@t AND RevokedAtUtc IS NULL",
            ("@n", nowUtc.ToString("o")), ("@t", tokenHash)) == 1;
    }

    public bool UnbindPush(string installationId, DateTime nowUtc)
    {
        using var c = _db.Open();
        return Db.Exec(c, """
            UPDATE Devices SET PushProvider=NULL, PushToken=NULL, PushEnvironment=NULL, LastSeenAtUtc=@n
            WHERE InstallationId=@i
            """, ("@n", nowUtc.ToString("o")), ("@i", installationId)) == 1;
    }

    public (string? Provider, string? Token, string? Environment) GetPushBinding(string installationId)
    {
        using var c = _db.Open();
        using var r = Db.Query(c, "SELECT PushProvider,PushToken,PushEnvironment FROM Devices WHERE InstallationId=@i", ("@i", installationId));
        if (!r.Read()) return (null, null, null);
        return (r.IsDBNull(0) ? null : r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2));
    }

    public bool SetPushBinding(string installationId, string provider, string token, string environment, DateTime nowUtc)
    {
        using var c = _db.Open();
        return Db.Exec(c, """
            UPDATE Devices SET PushProvider=@p, PushToken=@t, PushEnvironment=@e, LastSeenAtUtc=@n
            WHERE InstallationId=@i AND Active=1
            """, ("@p", provider), ("@t", token), ("@e", environment), ("@n", nowUtc.ToString("o")), ("@i", installationId)) == 1;
    }

    private static string SanitizePlatform(string? platform) =>
        platform is "android" or "ios" ? platform : "unknown";

    private static readonly JsonSerializerOptions JsonOpts = new() { WriteIndented = false };
}
