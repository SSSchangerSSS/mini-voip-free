using System.Text.Json;
using Microsoft.Data.Sqlite;
using Smi.Control.Database;

namespace Smi.Control.Calls;

public sealed record CallRow(
    string CallId, string AttemptId, string CallerExt, string CalleeExt, int CalleeDeviceGeneration,
    CallState State, DateTime DeadlineUtc, DateTime CreatedAtUtc,
    DateTime? PushSentAtUtc, DateTime? DeviceReadyAtUtc, DateTime? SipDialStartedAtUtc,
    DateTime? AcceptedAtUtc, DateTime? ConnectedAtUtc, DateTime? EndRequestedAtUtc,
    DateTime? EndedAtUtc, EndReason? EndReason, long Revision,
    string? PbxInstanceId, string? PbxUniqueId, string? ChannelName)
{
    public bool IsParty(string extension) => CallerExt == extension || CalleeExt == extension;
}

public sealed record AdmissionOutcome(AdmissionResult Result, CallRow? Call);

/// <summary>
/// Persistent call/slot logic (spec 5.2, 5.3, 6.3). Every mutation runs inside an
/// IMMEDIATE transaction with state conditions — the unique CallSlots primary key is
/// what actually prevents concurrent double-booking, not application-level checks.
/// </summary>
public sealed class CallStore
{
    private readonly Db _db;
    private readonly SmiConfig _cfg;
    public CallStore(Db db, SmiConfig cfg) { _db = db; _cfg = cfg; }

    private const string CallColumns =
        "CallId,AttemptId,CallerExt,CalleeExt,CalleeDeviceGeneration,State,DeadlineUtc,CreatedAtUtc," +
        "PushSentAtUtc,DeviceReadyAtUtc,SipDialStartedAtUtc,AcceptedAtUtc,ConnectedAtUtc,EndRequestedAtUtc," +
        "EndedAtUtc,EndReason,Revision,PbxInstanceId,PbxUniqueId,ChannelName";

    public AdmissionOutcome Admit(string callerExt, string calleeExt, string attemptId,
        string pbxInstanceId, string pbxUniqueId, string channelName, DateTime nowUtc)
    {
        if (callerExt == calleeExt) return new AdmissionOutcome(AdmissionResult.SelfCall, null);
        var callId = Crypto.NewId();
        var deadline = nowUtc.AddSeconds(_cfg.SetupTimeoutSeconds);

        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        try
        {
            // duplicate attempt of the same caller → return the original call (idempotent)
            var existing = ReadByAttempt(c, callerExt, attemptId);
            if (existing is not null)
                return new AdmissionOutcome(AdmissionResult.DuplicateAttempt, existing);

            // caller already holds a slot → busy, regardless of callee state (T28/T29)
            var callerSlot = Db.Scalar(c, "SELECT CallId FROM CallSlots WHERE Extension=@e", ("@e", callerExt));
            if (callerSlot is not null)
                return new AdmissionOutcome(AdmissionResult.Busy, null);

            // destination must exist and be enabled
            var callee = ReadExtension(c, calleeExt);
            if (callee is null || !callee.Value.Enabled)
                return new AdmissionOutcome(AdmissionResult.UnknownOrDisabledCallee, null);

            // one active device per extension — its generation gates pushes and ready
            var gen = Db.ScalarLong(c, "SELECT DeviceGeneration FROM Devices WHERE Extension=@e AND Active=1", ("@e", calleeExt));
            if (gen is null)
                return new AdmissionOutcome(AdmissionResult.UnknownOrDisabledCallee, null);

            var state = CallState.Pending.ToString();
            Exec(c, """
                INSERT INTO Calls(CallId,AttemptId,CallerExt,CalleeExt,CalleeDeviceGeneration,State,DeadlineUtc,
                    CreatedAtUtc,Revision,PbxInstanceId,PbxUniqueId,ChannelName)
                VALUES(@id,@att,@caller,@callee,@gen,@st,@dl,@cr,1,@pi,@pu,@ch)
                """,
                ("@id", callId), ("@att", attemptId), ("@caller", callerExt), ("@callee", calleeExt),
                ("@gen", gen.Value), ("@st", state), ("@dl", deadline.ToString("o")), ("@cr", nowUtc.ToString("o")),
                ("@pi", pbxInstanceId), ("@pu", pbxUniqueId), ("@ch", channelName));

            // The two slot inserts are the actual gate: unique primary key per extension.
            Exec(c, "INSERT INTO CallSlots(Extension,CallId) VALUES(@e,@id)", ("@e", callerExt), ("@id", callId));
            Exec(c, "INSERT INTO CallSlots(Extension,CallId) VALUES(@e,@id)", ("@e", calleeExt), ("@id", callId));
            tx.Commit();
            var call = Read(c, callId)!;
            return new AdmissionOutcome(AdmissionResult.Created, call);
        }
        catch (SqliteException ex) when (ex.SqliteErrorCode == 19) // constraint → busy
        {
            tx.Rollback();
            return new AdmissionOutcome(AdmissionResult.Busy, null);
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    public CallRow? GetById(string callId)
    {
        using var c = _db.Open();
        return Read(c, callId);
    }

    public CallRow? GetByAttempt(string callerExt, string attemptId)
    {
        using var c = _db.Open();
        return ReadByAttempt(c, callerExt, attemptId);
    }

    public CallRow? GetCurrentFor(string extension)
    {
        using var c = _db.Open();
        using var r = Query(c, $"""
            SELECT {CallColumns} FROM Calls
            WHERE State != 'Ended' AND (CallerExt=@e OR CalleeExt=@e)
            ORDER BY CreatedAtUtc DESC LIMIT 1
            """, ("@e", extension));
        return r.Read() ? Map(r) : null;
    }

    public CallRow? GetByAttemptIdFor(string extension, string attemptId)
    {
        using var c = _db.Open();
        using var r = Query(c, $"""
            SELECT {CallColumns} FROM Calls
            WHERE CallerExt=@e AND AttemptId=@a LIMIT 1
            """, ("@e", extension), ("@a", attemptId));
        return r.Read() ? Map(r) : null;
    }

    /// <summary>Callee confirmed readiness. Idempotent; verifies deadline + device generation.</summary>
    public (CallRow? Call, string? Error) MarkDeviceReady(string callId, string calleeExt, int deviceGeneration, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var call = Read(c, callId);
        if (call is null || call.CalleeExt != calleeExt) return (null, "CALL_NOT_FOUND");
        if (call.State == CallState.Ended) return (call, "CALL_ENDED");
        if (call.State is CallState.Connected or CallState.Connecting) return (call, null); // late/no-op ready
        if (nowUtc > call.DeadlineUtc) { EndTx(c, call, EndReason.Expired, nowUtc, callerCancelled: false); tx.Commit(); return (Read(c, callId), "CALL_EXPIRED"); }
        if (deviceGeneration != call.CalleeDeviceGeneration) return (call, "STALE_DEVICE");

        var updated = Exec(c, """
            UPDATE Calls SET DeviceReadyAtUtc=@t, Revision=Revision+1
            WHERE CallId=@id AND State='Pending' AND DeviceReadyAtUtc IS NULL
            """, ("@t", nowUtc.ToString("o")), ("@id", callId));
        tx.Commit();
        return (updated == 1 ? Read(c, callId) : call, null);
    }

    /// <summary>Register accept intent (never answers SIP). Pending → Connecting.</summary>
    public (CallRow? Call, string? Error) Accept(string callId, string calleeExt, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var call = Read(c, callId);
        if (call is null || call.CalleeExt != calleeExt) return (null, "CALL_NOT_FOUND");
        if (call.State == CallState.Ended) return (call, "CALL_ENDED");
        if (call.State == CallState.Connecting || call.State == CallState.Connected) return (call, null); // idempotent
        if (nowUtc > call.DeadlineUtc) { EndTx(c, call, EndReason.Expired, nowUtc, false); tx.Commit(); return (Read(c, callId), "CALL_EXPIRED"); }

        var updated = Exec(c, """
            UPDATE Calls SET State='Connecting', AcceptedAtUtc=@t, Revision=Revision+1
            WHERE CallId=@id AND State='Pending'
            """, ("@t", nowUtc.ToString("o")), ("@id", callId));
        if (updated != 1) { tx.Rollback(); return (Read(c, callId), "INVALID_TRANSITION"); }
        tx.Commit();
        return (Read(c, callId), null);
    }

    public (CallRow? Call, string? Error) Decline(string callId, string calleeExt, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var call = Read(c, callId);
        if (call is null || call.CalleeExt != calleeExt) return (null, "CALL_NOT_FOUND");
        if (call.State == CallState.Connected) return (call, "INVALID_TRANSITION"); // use end
        if (call.State == CallState.Ended) return (call, null);
        EndTx(c, call, EndReason.Declined, nowUtc, false);
        tx.Commit();
        return (Read(c, callId), null);
    }

    /// <summary>End request from either party (or system). Records EndRequestedAtUtc when requested via API.</summary>
    public (CallRow? Call, string? Error) End(string callId, string requesterExt, EndReason reason, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var call = Read(c, callId);
        if (call is null || !call.IsParty(requesterExt)) return (null, "CALL_NOT_FOUND");
        if (call.State == CallState.Ended) return (call, null);
        var updated = Exec(c, "UPDATE Calls SET EndRequestedAtUtc=@t WHERE CallId=@id AND EndRequestedAtUtc IS NULL",
            ("@t", nowUtc.ToString("o")), ("@id", callId));
        EndTx(c, call, reason, nowUtc, callerCancelled: reason == EndReason.CallerCancelled && call.CallerExt == requesterExt);
        tx.Commit();
        _ = updated;
        return (Read(c, callId), null);
    }

    /// <summary>PBX evidence: both legs bridged. Pending may jump directly to Connected.</summary>
    public CallRow? MarkConnected(string callId, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var call = Read(c, callId);
        if (call is null || call.State is CallState.Ended or CallState.Connected) { tx.Commit(); return call; }
        Exec(c, """
            UPDATE Calls SET State='Connected', ConnectedAtUtc=@t, Revision=Revision+1
            WHERE CallId=@id
            """, ("@t", nowUtc.ToString("o")), ("@id", callId));
        tx.Commit();
        return Read(c, callId);
    }

    public CallRow? MarkPushSent(string callId, DateTime nowUtc)
    {
        using var c = _db.Open();
        Exec(c, "UPDATE Calls SET PushSentAtUtc=@t WHERE CallId=@id AND PushSentAtUtc IS NULL",
            ("@t", nowUtc.ToString("o")), ("@id", callId));
        return GetById(callId);
    }

    public CallRow? MarkDialStarted(string callId, DateTime nowUtc)
    {
        using var c = _db.Open();
        Exec(c, "UPDATE Calls SET SipDialStartedAtUtc=@t, Revision=Revision+1 WHERE CallId=@id AND SipDialStartedAtUtc IS NULL",
            ("@t", nowUtc.ToString("o")), ("@id", callId));
        return GetById(callId);
    }

    /// <summary>Expired pending calls → Ended/Expired (timer-driven; spec 5.2 step 7 / T25).</summary>
    public IReadOnlyList<CallRow> ExpireOverdue(DateTime nowUtc)
    {
        var ended = new List<CallRow>();
        using (var c = _db.Open())
        {
            using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
            using (var r = Query(c, "SELECT CallId FROM Calls WHERE State IN ('Pending','Connecting') AND DeadlineUtc < @n",
                       ("@n", nowUtc.ToString("o"))))
            {
                while (r.Read()) ended.Add(Read(c, r.GetString(0))!);
            }
            foreach (var call in ended) EndTx(c, call, EndReason.Expired, nowUtc, false);
            tx.Commit();
        }
        return ended;
    }

    /// <summary>Pending call without a live channel after a server/AMI restart (spec 5.5).</summary>
    public void EndWithReason(string callId, EndReason reason, DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var call = Read(c, callId);
        if (call is not null && call.State != CallState.Ended) EndTx(c, call, reason, nowUtc, false);
        tx.Commit();
    }

    public IReadOnlyList<CallRow> ListActive()
    {
        var list = new List<CallRow>();
        using var c = _db.Open();
        using var r = Query(c, $"SELECT {CallColumns} FROM Calls WHERE State != 'Ended'");
        while (r.Read()) list.Add(Map(r));
        return list;
    }

    /// <summary>Diagnostics retention: remove terminal calls older than N days; keep security data (spec 6.3).</summary>
    public int PurgeOld(DateTime nowUtc)
    {
        using var c = _db.Open();
        using var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable);
        var cutoff = nowUtc.AddDays(-_cfg.DiagnosticRetentionDays).ToString("o");
        Exec(c, """
            DELETE FROM CallSlots WHERE CallId IN (SELECT CallId FROM Calls WHERE State='Ended' AND EndedAtUtc < @cut);
            """, ("@cut", cutoff));
        var n = Exec(c, "DELETE FROM Calls WHERE State='Ended' AND EndedAtUtc < @cut", ("@cut", cutoff));
        tx.Commit();
        return n;
    }

    // ---- internals -------------------------------------------------------------

    /// <summary>Ends a call and frees both slots in the SAME transaction (PBX end is the authoritative trigger).</summary>
    private static void EndTx(SqliteConnection c, CallRow call, EndReason reason, DateTime nowUtc, bool callerCancelled)
    {
        if (call.State == CallState.Ended) return;
        CallStateMachine.EnsureTransition(call.State, CallState.Ended);
        var reasonText = callerCancelled && reason == EndReason.Completed ? EndReason.CallerCancelled.ToString() : reason.ToString();
        Exec(c, """
            UPDATE Calls SET State='Ended', EndedAtUtc=@t, EndReason=@r, Revision=Revision+1
            WHERE CallId=@id AND State != 'Ended'
            """, ("@t", nowUtc.ToString("o")), ("@r", reasonText), ("@id", call.CallId));
        Exec(c, "DELETE FROM CallSlots WHERE CallId=@id", ("@id", call.CallId));
    }

    private static (string Extension, bool Enabled, string Hash, string Salt, int Iterations, int ConfigGen)? ReadExtension(SqliteConnection c, string ext)
    {
        using var r = Query(c, "SELECT Extension,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,ConfigurationGeneration FROM Extensions WHERE Extension=@e", ("@e", ext));
        if (!r.Read()) return null;
        return (r.GetString(0), r.GetInt64(1) == 1, r.GetString(2), r.GetString(3), (int)r.GetInt64(4), (int)r.GetInt64(5));
    }

    private static CallRow? Read(SqliteConnection c, string callId)
    {
        using var r = Query(c, $"SELECT {CallColumns} FROM Calls WHERE CallId=@id", ("@id", callId));
        return r.Read() ? Map(r) : null;
    }

    private static CallRow? ReadByAttempt(SqliteConnection c, string callerExt, string attemptId)
    {
        using var r = Query(c, $"SELECT {CallColumns} FROM Calls WHERE CallerExt=@e AND AttemptId=@a", ("@e", callerExt), ("@a", attemptId));
        return r.Read() ? Map(r) : null;
    }

    private static CallRow Map(SqliteDataReader r) => new(
        r.GetString(0), r.GetString(1), r.GetString(2), r.GetString(3), (int)r.GetInt64(4),
        Enum.Parse<CallState>(r.GetString(5)), DateTime.Parse(r.GetString(6)), DateTime.Parse(r.GetString(7)),
        NullDate(r, 8), NullDate(r, 9), NullDate(r, 10), NullDate(r, 11), NullDate(r, 12), NullDate(r, 13),
        NullDate(r, 14), r.IsDBNull(15) ? null : Enum.Parse<EndReason>(r.GetString(15)),
        r.GetInt64(16), r.IsDBNull(17) ? null : r.GetString(17), r.IsDBNull(18) ? null : r.GetString(18), r.IsDBNull(19) ? null : r.GetString(19));

    private static DateTime? NullDate(SqliteDataReader r, int i) => r.IsDBNull(i) ? null : DateTime.Parse(r.GetString(i));

    private static int Exec(SqliteConnection c, string sql, params (string Name, object? Value)[] p) => Db.Exec(c, sql, p);
    private static SqliteDataReader Query(SqliteConnection c, string sql, params (string Name, object? Value)[] p) => Db.Query(c, sql, p);
}
