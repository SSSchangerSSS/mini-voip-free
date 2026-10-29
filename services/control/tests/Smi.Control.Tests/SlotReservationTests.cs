using Smi.Control;
using Smi.Control.Calls;
using Smi.Control.Database;
using Xunit;

namespace Smi.Control.Tests;

/// <summary>
/// Real SQLite on a temp file — concurrent admissions must be serialized by the
/// unique CallSlots primary key inside IMMEDIATE transactions (spec 5.3, T28/T29),
/// not by application-level check-then-set.
/// </summary>
public class SlotReservationTests : IDisposable
{
    private readonly string _dbPath;
    private readonly SmiConfig _cfg;
    private readonly Db _db;
    private readonly CallStore _store;

    public SlotReservationTests()
    {
        _dbPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"smi-slot-{Guid.NewGuid():N}.db");
        _cfg = new SmiConfig { DbPath = _dbPath, Domain = "test.local", SetupTimeoutSeconds = 40 };
        _db = new Db(_cfg);
        _db.Migrate();
        _store = new CallStore(_db, _cfg);
        SeedExtension("101");
        SeedExtension("102");
        SeedExtension("103");
        SeedActiveDevice("102");
        SeedActiveDevice("103");
    }

    private void SeedExtension(string ext)
    {
        var (hash, salt, iters) = Crypto.HashPassword("test-password-123");
        using var c = _db.Open();
        Db.Exec(c, """
            INSERT INTO Extensions(Extension,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,SipSecret,ConfigurationGeneration,CreatedAtUtc,UpdatedAtUtc)
            VALUES(@e,1,@h,@s,@it,'sipsecret',1,@n,@n)
            """, ("@e", ext), ("@h", hash), ("@s", salt), ("@it", iters), ("@n", DateTime.UtcNow.ToString("o")));
    }

    private void SeedActiveDevice(string ext)
    {
        using var c = _db.Open();
        Db.Exec(c, """
            INSERT INTO Devices(InstallationId,Extension,Platform,DeviceGeneration,Active,LastSeenAtUtc)
            VALUES(@i,@e,'android',1,1,@n)
            """, ("@i", Guid.NewGuid().ToString()), ("@e", ext), ("@n", DateTime.UtcNow.ToString("o")));
    }

    [Fact]
    public void NormalAdmission_ReservesBothSlots_AndFreesThemOnEnd()
    {
        var outcome = _store.Admit("101", "102", Guid.NewGuid().ToString(), "inst", "pbx-1", "PJSIP/101-abc", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.Created, outcome.Result);

        // same caller, second attempt while first is alive → busy (one call per device)
        var second = _store.Admit("101", "103", Guid.NewGuid().ToString(), "inst", "pbx-2", "PJSIP/101-def", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.Busy, second.Result);

        // another caller to the same callee → busy (T28)
        var third = _store.Admit("103", "102", Guid.NewGuid().ToString(), "inst", "pbx-3", "PJSIP/103-abc", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.Busy, third.Result);

        // end → slots freed → new call allowed (T46 invariant)
        _store.End(outcome.Call!.CallId, "101", EndReason.Completed, DateTime.UtcNow);
        var again = _store.Admit("101", "102", Guid.NewGuid().ToString(), "inst", "pbx-4", "PJSIP/101-ghi", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.Created, again.Result);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task TerminalRequest_OnlyFirstAtomicTransitionMayTriggerPbxHangup(bool decline)
    {
        var admitted = _store.Admit("101", "102", Guid.NewGuid().ToString(), "inst", "pbx-1", "PJSIP/101-abc", DateTime.UtcNow).Call!;
        var results = await Task.WhenAll(Enumerable.Range(0, 2).Select(_ => Task.Run(() =>
            decline ? _store.Decline(admitted.CallId, "102", DateTime.UtcNow)
                : _store.End(admitted.CallId, "101", EndReason.Completed, DateTime.UtcNow))));
        Assert.Single(results, r => r.Error is null);
        Assert.Single(results, r => r.Error == "CALL_ENDED");
        Assert.All(results, r => Assert.Equal(CallState.Ended, r.Call!.State));
        Assert.Equal(results[0].Call!.Revision, results[1].Call!.Revision);
        Assert.Empty(_store.ListActive());
    }

    [Fact]
    public void DuplicateAttempt_ReturnsSameCall_WithSameDeadline()
    {
        var attemptId = Guid.NewGuid().ToString();
        var first = _store.Admit("101", "102", attemptId, "inst", "pbx-1", "PJSIP/101-abc", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.Created, first.Result);
        var dup = _store.Admit("101", "102", attemptId, "inst", "pbx-1", "PJSIP/101-abc", DateTime.UtcNow.AddSeconds(5));
        Assert.Equal(AdmissionResult.DuplicateAttempt, dup.Result);
        Assert.Equal(first.Call!.CallId, dup.Call!.CallId);
        Assert.Equal(first.Call.DeadlineUtc, dup.Call.DeadlineUtc); // retry keeps the same UUID/deadline (spec 5.2 step 7)
    }

    [Fact]
    public void SelfCall_IsRejected()
    {
        var outcome = _store.Admit("101", "101", Guid.NewGuid().ToString(), "inst", "pbx-1", "PJSIP/101-abc", DateTime.UtcNow);
        Assert.Equal(AdmissionResult.SelfCall, outcome.Result);
    }

    [Fact]
    public async Task ConcurrentAdmissions_ToSameCallee_OnlyOneWins()
    {
        const int callers = 6;
        var tasks = Enumerable.Range(0, callers).Select(async i =>
        {
            var caller = i == 0 ? "101" : "103"; // both target 102; 103 vs 101 — one is rejected as busy
            await Task.Yield();
            return caller;
        }).ToList();

        // run the same caller/destination pair twice concurrently to force the race
        var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Task.Run(() =>
        {
            var caller = Random.Shared.Next(0, 2) == 0 ? "101" : "103";
            return _store.Admit(caller, "102", Guid.NewGuid().ToString(), "inst", $"pbx-{Guid.NewGuid():N}", $"PJSIP/{caller}-x", DateTime.UtcNow);
        })));

        Assert.Equal(1, results.Count(r => r.Result == AdmissionResult.Created));
        Assert.All(results.Where(r => r.Result != AdmissionResult.Created), r => Assert.Equal(AdmissionResult.Busy, r.Result));
        _ = tasks;
    }

    public void Dispose()
    {
        try { File.Delete(_dbPath); File.Delete(_dbPath + "-wal"); File.Delete(_dbPath + "-shm"); } catch { }
    }
}
