using System.Collections.Concurrent;

namespace Smi.Control;

/// <summary>
/// Central definition of runtime configuration (spec sections 4.2, 7.1, 11.3).
/// Everything comes from environment / secret files. There is NO insecure default fallback:
/// missing critical config degrades readiness and the service fails closed (spec 5.5).
/// </summary>
public sealed class SmiConfig
{
    public string DbPath { get; init; } = "./data/control/smi.db";
    public string DataDir { get; init; } = "./data";
    /// <summary>Directory of rendered PBX config files (shared volume with the pbx service).</summary>
    public string PbxCfgDir { get; init; } = "./data/asterisk/config";
    /// <summary>Public domain users configure in the app; also SIP realm. Required for /me and provisioning.</summary>
    public string? Domain { get; init; }

    public int SetupTimeoutSeconds { get; init; } = 40;
    public int AmiAdmissionTimeoutSeconds { get; init; } = 3;
    public int PendingStatusPollMs { get; init; } = 1000;
    public int ReconnectGraceSeconds { get; init; } = 15;
    public int SessionIdleDays { get; init; } = 90;
    public int DiagnosticRetentionDays { get; init; } = 7;

    public string AmiHost { get; init; } = "127.0.0.1";
    public int AmiPort { get; init; } = 5038;
    public string AmiUsername { get; init; } = "smi-control";
    /// <summary>Secret read from SMI_AMI_SECRET_FILE (never from plain env in production).</summary>
    public string? AmiSecret { get; init; }

    // Push providers (BLOCKED until employer-supplied secrets exist; spec section 19)
    public string? ApnsP8Path { get; init; }
    public string? ApnsKeyId { get; init; }
    public string? ApnsTeamId { get; init; }
    public string? ApnsBundleId { get; init; }
    public string ApnsEnvironment { get; init; } = "production";

    public string? FcmServiceAccountPath { get; init; }
    public string? FcmProjectId { get; init; }

    public bool TurnEnabled { get; init; }

    public string WssUrl => Domain is null ? "SMI_DOMAIN_NOT_CONFIGURED" : $"wss://{Domain}/ws";
    public string SipRealm => Domain ?? "SMI_DOMAIN_NOT_CONFIGURED";

    public IReadOnlyList<string> MissingCritical
    {
        get
        {
            var list = new List<string>();
            if (string.IsNullOrWhiteSpace(Domain)) list.Add("SMI_DOMAIN");
            if (AmiSecret is null) list.Add("SMI_AMI_SECRET_FILE");
            return list;
        }
    }

    public static SmiConfig FromEnvironment()
    {
        string? ReadFileSecret(string? path)
        {
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) return null;
            var value = File.ReadAllText(path).Trim();
            return value.Length == 0 ? null : value;
        }

        int EnvInt(string name, int fallback) =>
            int.TryParse(Environment.GetEnvironmentVariable(name), out var v) ? v : fallback;

        return new SmiConfig
        {
            DbPath = Environment.GetEnvironmentVariable("SMI_DB_PATH") ?? "./data/control/smi.db",
            DataDir = Environment.GetEnvironmentVariable("SMI_DATA_DIR") ?? "./data",
            PbxCfgDir = Environment.GetEnvironmentVariable("SMI_PBX_CFG_DIR") ?? "./data/asterisk/config",
            Domain = Environment.GetEnvironmentVariable("SMI_DOMAIN"),
            SetupTimeoutSeconds = EnvInt("SMI_SETUP_TIMEOUT_SECONDS", 40),
            AmiAdmissionTimeoutSeconds = EnvInt("SMI_AMI_ADMISSION_TIMEOUT_SECONDS", 3),
            PendingStatusPollMs = EnvInt("SMI_PENDING_STATUS_POLL_MS", 1000),
            ReconnectGraceSeconds = EnvInt("SMI_RECONNECT_GRACE_SECONDS", 15),
            SessionIdleDays = EnvInt("SMI_SESSION_IDLE_DAYS", 90),
            DiagnosticRetentionDays = EnvInt("SMI_DIAGNOSTIC_RETENTION_DAYS", 7),
            AmiHost = Environment.GetEnvironmentVariable("SMI_AMI_HOST") ?? "127.0.0.1",
            AmiPort = EnvInt("SMI_AMI_PORT", 5038),
            AmiUsername = Environment.GetEnvironmentVariable("SMI_AMI_USERNAME") ?? "smi-control",
            AmiSecret = ReadFileSecret(Environment.GetEnvironmentVariable("SMI_AMI_SECRET_FILE")),
            ApnsP8Path = Environment.GetEnvironmentVariable("SMI_APNS_P8_FILE"),
            ApnsKeyId = Environment.GetEnvironmentVariable("SMI_APNS_KEY_ID"),
            ApnsTeamId = Environment.GetEnvironmentVariable("SMI_APNS_TEAM_ID"),
            ApnsBundleId = Environment.GetEnvironmentVariable("SMI_APNS_BUNDLE_ID"),
            ApnsEnvironment = Environment.GetEnvironmentVariable("SMI_APNS_ENVIRONMENT") ?? "production",
            FcmServiceAccountPath = Environment.GetEnvironmentVariable("SMI_FCM_SERVICE_ACCOUNT_FILE"),
            FcmProjectId = Environment.GetEnvironmentVariable("SMI_FCM_PROJECT_ID"),
            TurnEnabled = string.Equals(Environment.GetEnvironmentVariable("TURN_ENABLED"), "true", StringComparison.OrdinalIgnoreCase),
        };
    }
}

/// <summary>
/// Login throttling: combined IP+extension window (spec 7.1: ~5 failures/minute),
/// implemented in-process. Failure messages never disclose whether an account exists.
/// </summary>
public static class LoginThrottle
{
    private sealed record Counter(DateTime WindowStart, int Failures);
    private static readonly ConcurrentDictionary<string, Counter> Counters = new();

    public static bool IsBlocked(string ip, string extension)
    {
        var key = $"{ip}|{extension}";
        if (!Counters.TryGetValue(key, out var c)) return false;
        if (DateTime.UtcNow - c.WindowStart >= TimeSpan.FromMinutes(1)) return false;
        return c.Failures >= 5;
    }

    public static void RecordFailure(string ip, string extension)
    {
        var key = $"{ip}|{extension}";
        Counters.AddOrUpdate(key,
            _ => new Counter(DateTime.UtcNow, 1),
            (_, c) => DateTime.UtcNow - c.WindowStart >= TimeSpan.FromMinutes(1)
                ? new Counter(DateTime.UtcNow, 1)
                : c with { Failures = c.Failures + 1 });
    }

    public static void Reset(string ip, string extension) => Counters.TryRemove($"{ip}|{extension}", out _);
}
