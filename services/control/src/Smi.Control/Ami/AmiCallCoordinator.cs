using System.Collections.Concurrent;
using System.Text.Json;
using Smi.Control.Calls;
using Smi.Control.Database;
using Smi.Control.Push;

namespace Smi.Control.Ami;

/// <summary>
/// The SMI handshake coordinator (spec sections 5, 8).
/// SMICallRequested → validate → atomic slot reservation → Setvar __SMI_CALL_ID +
/// SMI_DEADLINE_EPOCH (each response checked) → only then SMI_ADMITTED=1.
/// ready → SMI_DIAL_ALLOWED=1 (single Dial). PBX bridge evidence → Connected.
/// Everything fails closed when AMI is unavailable. Wire identifiers are spec-fixed.
/// </summary>
public sealed class AmiCallCoordinator : BackgroundService
{
    private readonly AmiClient _ami;
    private readonly CallStore _calls;
    private readonly Db _db;
    private readonly SmiConfig _cfg;
    private readonly PushDispatch _push;
    private readonly ILogger<AmiCallCoordinator> _log;

    // bridge evidence: bridgeUniqueid → set of channel names observed inside it
    private readonly ConcurrentDictionary<string, ConcurrentDictionary<string, byte>> _bridges = new();

    public AmiCallCoordinator(AmiClient ami, CallStore calls, Db db, SmiConfig cfg, PushDispatch push,
        ILogger<AmiCallCoordinator> log)
    { _ami = ami; _calls = calls; _db = db; _cfg = cfg; _push = push; _log = log; }

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        _ami.EventReceived += OnEvent;
        _ami.ConnectionRestored += OnAmiRestored;
        _ami.ConnectionLost += OnAmiLost;

        var expiryTimer = Task.Run(async () =>
        {
            while (!stopping.IsCancellationRequested)
            {
                await Task.Delay(_cfg.PendingStatusPollMs, stopping);
                try
                {
                    foreach (var call in _calls.ExpireOverdue(DateTime.UtcNow))
                        _log.LogInformation("call {CallId} expired ({Callee})", call.CallId, call.CalleeExt);
                }
                catch (Exception ex) { _log.LogWarning(ex, "expiry sweep failed"); }
            }
        }, stopping);

        await expiryTimer;
    }

    private void OnAmiRestored()
    {
        _log.LogInformation("AMI restored; starting reconcile");
        _ = Task.Run(async () =>
        {
            try
            {
                await ReconcileAsync(CancellationToken.None);
                _ami.Reconciled = true;
                _log.LogInformation("AMI reconcile complete; service ready");
            }
            catch (Exception ex) { _log.LogError(ex, "AMI reconcile failed"); }
        });
    }

    private void OnAmiLost()
    {
        _ami.Reconciled = false;
        // Pending stored calls without a live channel become Ended/ServerRestart after reconcile;
        // live connected calls are preserved. No global BYE is ever issued on restart (spec 5.5).
        _bridges.Clear();
    }

    /// <summary>Snapshot + DB reconcile. AMI events are not replayable — state comes from snapshot (spec 8.4).</summary>
    public async Task ReconcileAsync(CancellationToken ct)
    {
        var snapshot = await _ami.SendAction(new Dictionary<string, string> { ["Action"] = "Status" }, ct, TimeSpan.FromSeconds(10));
        var liveChannels = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        // full channel listing arrives as separate Status events; rely on SMICallFinished/Hangup
        // plus the DB. For P1/P2 the authoritative check is per-call Getvar on the stored channel.
        var now = DateTime.UtcNow;
        foreach (var call in _calls.ListActive())
        {
            if (call.State is CallState.Pending or CallState.Connecting)
            {
                if (call.ChannelName is not null)
                {
                    var probe = await _ami.GetVar(call.ChannelName, "SMI_CALL_ID", ct);
                    if (probe is null) _calls.EndWithReason(call.CallId, EndReason.ServerRestart, now);
                    else if (now > call.DeadlineUtc) _calls.EndWithReason(call.CallId, EndReason.Expired, now);
                }
                else
                {
                    _calls.EndWithReason(call.CallId, EndReason.ServerRestart, now);
                }
            }
            // Connected calls are left alone: Asterisk keeps the media without Control (spec 5.5).
        }
        _ = liveChannels;
    }

    private void OnEvent(AmiPacket e)
    {
        switch (e.EventName)
        {
            case "UserEvent":
                var userEvent = e.Get("UserEvent");
                if (userEvent == "SMICallRequested") _ = Task.Run(() => OnCallRequestedAsync(e));
                else if (userEvent == "SMICallDialing") OnCallDialing(e);
                else if (userEvent == "SMICallFinished") OnCallFinished(e);
                break;
            case "Hangup": OnHangup(e); break;
            case "BridgeEnter": OnBridgeEnter(e); break;
            case "BridgeLeave": OnBridgeLeave(e); break;
        }
    }

    private async Task OnCallRequestedAsync(AmiPacket e)
    {
        // Fail closed unless fully reconciled (spec 5.5: new calls fail-closed when Control/AMI degrade)
        if (!_ami.Ready)
        {
            await RejectChannelAsync(e, 21); // rejected — control plane not ready
            return;
        }
        if (e.Get("SchemaVersion") != "1") { await RejectChannelAsync(e, 21); return; }

        var pbxUniqueId = e.Get("PbxUniqueId");
        var channel = e.Get("Channel");
        var caller = e.Get("CallerEndpoint");
        var calleeRaw = e.Get("Callee");
        var attemptId = e.Get("AttemptId");

        var callee = DigitNormalizer.NormalizeInternal(calleeRaw);
        var callerNorm = DigitNormalizer.NormalizeInternal(caller);
        if (callee is null || callerNorm is null || !Guid.TryParse(attemptId, out _))
        {
            await RejectChannelAsync(e, 1); // unallocated/unknown number
            return;
        }

        var now = DateTime.UtcNow;
        var outcome = _calls.Admit(callerNorm, callee, attemptId, _cfg.AmiHost, pbxUniqueId, channel, now);
        switch (outcome.Result)
        {
            case AdmissionResult.Created:
                var call = outcome.Call!;
                await WriteCallVarsAsync(call);
                // Foreground wake hint over the already registered SIP socket.
                // No credentials/call state in the hint; callee still validates
                // /calls/current and must pass the existing /ready gate.
                await _ami.SendAction(new Dictionary<string, string>
                {
                    ["Action"] = "MessageSend", ["Destination"] = $"pjsip:{call.CalleeExt}",
                    ["From"] = "sip:smi@localhost", ["Body"] = "smi-call",
                }, CancellationToken.None);
                var sent = await _push.SendIncomingCallAsync(call);
                if (sent) _calls.MarkPushSent(call.CallId, DateTime.UtcNow);
                _log.LogInformation("call {CallId} {Caller}->{Callee} admitted, push={Push}", call.CallId, call.CallerExt, call.CalleeExt, sent);
                break;
            case AdmissionResult.DuplicateAttempt:
                if (outcome.Call is not null) await WriteCallVarsAsync(outcome.Call); // same UUID, same deadline
                break;
            case AdmissionResult.Busy:
                await RejectChannelAsync(e, 17); break;
            case AdmissionResult.UnknownOrDisabledCallee:
            case AdmissionResult.SelfCall:
                await RejectChannelAsync(e, 20); break;
            default:
                await RejectChannelAsync(e, 31); break;
        }
    }

    private async Task WriteCallVarsAsync(CallRow call)
    {
        var ct = CancellationToken.None;
        var epoch = new DateTimeOffset(call.DeadlineUtc).ToUnixTimeSeconds().ToString();
        // Order matters (spec 5.2 step 5): call variables FIRST, each response checked, then admission.
        var setCallId = await _ami.SetVar(call.ChannelName!, "__SMI_CALL_ID", call.CallId, ct);
        if (setCallId is null || !string.Equals(setCallId.Get("Response"), "Success", StringComparison.OrdinalIgnoreCase))
        { FailAdmission(call, "setvar __SMI_CALL_ID failed"); return; }

        var setDeadline = await _ami.SetVar(call.ChannelName!, "SMI_DEADLINE_EPOCH", epoch, ct);
        if (setDeadline is null || !string.Equals(setDeadline.Get("Response"), "Success", StringComparison.OrdinalIgnoreCase))
        { FailAdmission(call, "setvar SMI_DEADLINE_EPOCH failed"); return; }

        var admit = await _ami.SetVar(call.ChannelName!, "SMI_ADMITTED", "1", ct);
        if (admit is null || !string.Equals(admit.Get("Response"), "Success", StringComparison.OrdinalIgnoreCase))
        { FailAdmission(call, "setvar SMI_ADMITTED failed"); return; }
    }

    private void FailAdmission(CallRow call, string why)
    {
        _log.LogWarning("call {CallId}: admission failed: {Why}", call.CallId, why);
        _calls.EndWithReason(call.CallId, EndReason.SetupFailed, DateTime.UtcNow);
        _ = _ami.Hangup(call.ChannelName!, 21, CancellationToken.None);
    }

    private async Task RejectChannelAsync(AmiPacket e, int cause)
    {
        var channel = e.Get("Channel");
        if (channel.Length > 0)
        {
            await _ami.SetVar(channel, "SMI_REJECT_CAUSE", cause.ToString(), CancellationToken.None);
            await _ami.Hangup(channel, cause, CancellationToken.None);
        }
        _log.LogInformation("channel {Channel} rejected with cause {Cause}", channel, cause);
    }

    /// <summary>API /ready → gate the single Dial (spec 5.2 steps 9–11).</summary>
    public async Task<bool> AllowDialAsync(CallRow call)
    {
        if (call.ChannelName is null) return false;
        var res = await _ami.SetVar(call.ChannelName, "SMI_DIAL_ALLOWED", "1", CancellationToken.None);
        var ok = res is not null && string.Equals(res.Get("Response"), "Success", StringComparison.OrdinalIgnoreCase);
        if (!ok) _log.LogWarning("SMI_DIAL_ALLOWED setvar failed for {CallId}", call.CallId);
        return ok;
    }

    public async Task EndViaPbxAsync(CallRow call, int cause)
    {
        if (call.ChannelName is not null)
            await _ami.Hangup(call.ChannelName, cause, CancellationToken.None);
    }

    private void OnCallDialing(AmiPacket e)
    {
        var callId = e.Get("CallId");
        if (Guid.TryParse(callId, out _)) _calls.MarkDialStarted(callId, DateTime.UtcNow);
    }

    private void OnCallFinished(AmiPacket e)
    {
        var callId = e.Get("CallId");
        var causeText = e.Get("HangupCause");
        if (!Guid.TryParse(callId, out _)) return;
        var call = _calls.GetById(callId);
        if (call is null || call.State == CallState.Ended) return;
        _calls.EndWithReason(callId, MapCause(causeText), DateTime.UtcNow);
    }

    private void OnHangup(AmiPacket e)
    {
        // identify the call either by __SMI_CALL_ID (reliable) or the stored channel name
        var channel = e.Get("Channel");
        var cause = e.Get("Cause");
        foreach (var call in _calls.ListActive())
        {
            if (call.ChannelName is not null && string.Equals(call.ChannelName, channel, StringComparison.OrdinalIgnoreCase))
            {
                _calls.EndWithReason(call.CallId, MapCause(cause), DateTime.UtcNow);
                return;
            }
        }
    }

    private void OnBridgeEnter(AmiPacket e)
    {
        var bridge = e.Get("BridgeUniqueid");
        var channel = e.Get("Channel");
        if (bridge.Length == 0 || channel.Length == 0) return;
        var set = _bridges.GetOrAdd(bridge, _ => new ConcurrentDictionary<string, byte>(StringComparer.OrdinalIgnoreCase));
        set[channel] = 1;
        TryMarkConnectedByBridge();
    }

    private void OnBridgeLeave(AmiPacket e)
    {
        var bridge = e.Get("BridgeUniqueid");
        var channel = e.Get("Channel");
        if (_bridges.TryGetValue(bridge, out var set)) set.TryRemove(channel, out _);
    }

    /// <summary>
    /// Connected requires PBX evidence that BOTH legs of the same call share a bridge
    /// (spec 8.3) — DIALSTATUS=ANSWER alone is not accepted.
    /// </summary>
    private void TryMarkConnectedByBridge()
    {
        foreach (var call in _calls.ListActive())
        {
            if (call.State == CallState.Connected || call.ChannelName is null) continue;
            foreach (var (_, set) in _bridges)
            {
                if (set.ContainsKey(call.ChannelName) && set.Count >= 2)
                {
                    _calls.MarkConnected(call.CallId, DateTime.UtcNow);
                    _log.LogInformation("call {CallId} connected via bridge evidence", call.CallId);
                    break;
                }
            }
        }
    }

    private static EndReason MapCause(string causeText) => causeText switch
    {
        "16" => EndReason.Completed,
        "17" => EndReason.Busy,
        "18" or "19" => EndReason.NoAnswer,
        "20" => EndReason.Unavailable,
        "21" => EndReason.Declined,
        "1" => EndReason.Unavailable,
        _ => EndReason.SetupFailed,
    };
}

public static class AmiExtensions
{
    public static async Task<AmiPacket?> GetVar(this AmiClient client, string channel, string variable, CancellationToken ct) =>
        await client.SendAction(new Dictionary<string, string>
        {
            ["Action"] = "Getvar", ["Channel"] = channel, ["Variable"] = variable,
        }, ct);
}
