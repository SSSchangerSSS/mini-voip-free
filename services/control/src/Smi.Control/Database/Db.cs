using System.Data;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.Sqlite;

namespace Smi.Control.Database;

/// <summary>
/// Local SQLite access (spec 6.3): WAL, foreign keys, busy timeout, numbered
/// migrations with checksum. No ORM — Microsoft.Data.Sqlite with parameterized SQL.
/// One connection per logical operation; SQLite serializes writers.
/// </summary>
public sealed class Db
{
    private readonly string _path;
    public string Path => _path;
    private readonly object _migrateLock = new();
    private bool _migrated;

    public Db(SmiConfig config)
    {
        _path = config.DbPath;
        var dir = System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(_path));
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
    }

    public SqliteConnection Open()
    {
        var cs = new SqliteConnectionStringBuilder
        {
            DataSource = System.IO.Path.GetFullPath(_path),
            Mode = SqliteOpenMode.ReadWriteCreate,
            Pooling = false,
        }.ToString();
        var conn = new SqliteConnection(cs);
        conn.Open();
        Exec(conn, "PRAGMA journal_mode=WAL");
        Exec(conn, "PRAGMA foreign_keys=ON");
        Exec(conn, "PRAGMA busy_timeout=5000");
        return conn;
    }

    public static int Exec(SqliteConnection c, string sql, params (string Name, object? Value)[] p)
    {
        using var cmd = c.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (name, value) in p) cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return cmd.ExecuteNonQuery();
    }

    public static object? Scalar(SqliteConnection c, string sql, params (string Name, object? Value)[] p)
    {
        using var cmd = c.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (name, value) in p) cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return cmd.ExecuteScalar();
    }

    public static long? ScalarLong(SqliteConnection c, string sql, params (string Name, object? Value)[] p) =>
        Scalar(c, sql, p) is long v ? v : null;

    public static SqliteDataReader Query(SqliteConnection c, string sql, params (string Name, object? Value)[] p)
    {
        var cmd = c.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (name, value) in p) cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return cmd.ExecuteReader();
    }

    /// <summary>
    /// Begin a write-locking transaction — no check-then-set races.
    /// Microsoft.Data.Sqlite maps IsolationLevel.Serializable to "BEGIN IMMEDIATE".
    /// </summary>
    public static SqliteTransaction BeginImmediate(SqliteConnection c) =>
        c.BeginTransaction(IsolationLevel.Serializable);

    public void Migrate()
    {
        lock (_migrateLock)
        {
            if (_migrated) return;
            using var c = Open();
            using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
            Exec(c, """
                CREATE TABLE IF NOT EXISTS SchemaMigrations(
                    Version INTEGER PRIMARY KEY,
                    Name TEXT NOT NULL,
                    Checksum TEXT NOT NULL,
                    AppliedAtUtc TEXT NOT NULL)
                """, ("@tx", 1));
            foreach (var m in Migrations.All)
            {
                var existing = Scalar(c, "SELECT Checksum FROM SchemaMigrations WHERE Version=@v", ("@v", m.Version)) as string;
                if (existing is not null)
                {
                    if (!string.Equals(existing, m.Checksum, StringComparison.Ordinal))
                        throw new InvalidOperationException($"migration {m.Version} checksum drift: applied={existing} code={m.Checksum}");
                    continue;
                }
                foreach (var stmt in SplitStatements(m.Sql)) Exec(c, stmt);
                Exec(c, "INSERT INTO SchemaMigrations(Version,Name,Checksum,AppliedAtUtc) VALUES(@v,@n,@cs,@at)",
                    ("@v", m.Version), ("@n", m.Name), ("@cs", m.Checksum), ("@at", DateTime.UtcNow.ToString("o")));
            }
            tx.Commit();
            _migrated = true;
        }
    }

    private static IEnumerable<string> SplitStatements(string sql)
    {
        // simple splitter on ';' at line ends — migrations are authored accordingly
        var parts = sql.Split(";\n", StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        foreach (var p in parts)
        {
            var s = p.TrimEnd(';');
            if (s.Length > 0) yield return s + ";";
        }
    }

    private static string Sha256Hex(string input) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(input))).ToLowerInvariant();
}

public sealed record Migration(int Version, string Name, string Sql)
{
    public string Checksum { get; } =
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(Sql))).ToLowerInvariant();
}

public static class Migrations
{
    public static readonly IReadOnlyList<Migration> All = new[]
    {
        new Migration(1, "baseline_smi_v1", """
            CREATE TABLE Extensions(
                Extension TEXT PRIMARY KEY,
                Enabled INTEGER NOT NULL DEFAULT 1,
                PasswordHash TEXT NOT NULL,
                PasswordSalt TEXT NOT NULL,
                Pbkdf2Iterations INTEGER NOT NULL,
                SipSecret TEXT NOT NULL,
                ConfigurationGeneration INTEGER NOT NULL DEFAULT 1,
                CreatedAtUtc TEXT NOT NULL,
                UpdatedAtUtc TEXT NOT NULL);

            CREATE TABLE Devices(
                InstallationId TEXT PRIMARY KEY,
                Extension TEXT NOT NULL REFERENCES Extensions(Extension),
                Platform TEXT NOT NULL,
                DeviceGeneration INTEGER NOT NULL DEFAULT 1,
                Active INTEGER NOT NULL DEFAULT 1,
                PushProvider TEXT,
                PushToken TEXT,
                PushEnvironment TEXT,
                Capabilities TEXT,
                LastSeenAtUtc TEXT);

            CREATE UNIQUE INDEX UX_Devices_ActiveExt ON Devices(Extension) WHERE Active = 1;

            CREATE TABLE Sessions(
                TokenHash TEXT PRIMARY KEY,
                InstallationId TEXT NOT NULL REFERENCES Devices(InstallationId),
                Extension TEXT NOT NULL,
                CreatedAtUtc TEXT NOT NULL,
                IdleExpiresAtUtc TEXT NOT NULL,
                RevokedAtUtc TEXT);

            CREATE INDEX IX_Sessions_Device ON Sessions(InstallationId);

            CREATE TABLE Calls(
                CallId TEXT PRIMARY KEY,
                AttemptId TEXT NOT NULL,
                CallerExt TEXT NOT NULL,
                CalleeExt TEXT NOT NULL,
                CalleeDeviceGeneration INTEGER NOT NULL,
                State TEXT NOT NULL,
                DeadlineUtc TEXT NOT NULL,
                CreatedAtUtc TEXT NOT NULL,
                PushSentAtUtc TEXT,
                DeviceReadyAtUtc TEXT,
                SipDialStartedAtUtc TEXT,
                AcceptedAtUtc TEXT,
                ConnectedAtUtc TEXT,
                EndRequestedAtUtc TEXT,
                EndedAtUtc TEXT,
                EndReason TEXT,
                Revision INTEGER NOT NULL DEFAULT 1,
                PbxInstanceId TEXT,
                PbxUniqueId TEXT,
                ChannelName TEXT,
                UNIQUE(CallerExt, AttemptId));

            CREATE INDEX IX_Calls_CalleeState ON Calls(CalleeExt, State);
            CREATE INDEX IX_Calls_State ON Calls(State);

            CREATE TABLE CallSlots(
                Extension TEXT PRIMARY KEY,
                CallId TEXT NOT NULL REFERENCES Calls(CallId));

            CREATE TABLE PendingActions(
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                Kind TEXT NOT NULL,
                CallId TEXT,
                Payload TEXT NOT NULL,
                Attempts INTEGER NOT NULL DEFAULT 0,
                NextAttemptAtUtc TEXT,
                DeadlineUtc TEXT,
                CreatedAtUtc TEXT NOT NULL);

            CREATE TABLE NativeEventLog(
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                CallId TEXT,
                Event TEXT NOT NULL,
                Detail TEXT NOT NULL,
                AtUtc TEXT NOT NULL);
            """),
    };
}
