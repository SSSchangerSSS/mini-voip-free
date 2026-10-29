using System.Collections.Concurrent;
using System.Net.Sockets;
using System.Text;

namespace Smi.Control.Ami;

public sealed record AmiPacket(string Type, string? EventName, string? ActionId, IReadOnlyDictionary<string, string> Fields)
{
    public string Get(string key, string fallback = "") =>
        Fields.TryGetValue(key, out var v) ? v : Fields.TryGetValue(_canon(key), out var v2) ? v2 : fallback;

    private static string _canon(string key) =>
        key.Length == 0 ? key : char.ToLowerInvariant(key[0]) + key[1..];
}

/// <summary>
/// Minimal loopback AMI client (spec 8.4): long-lived connection, dedicated login,
/// heartbeat, backoff+reconnect, ActionID matching. The parser tolerates TCP
/// fragmentation, multiple packets per read, CRLF and LF, and interleaved
/// events/responses. Actions: Login/Ping/Logoff, Setvar/Getvar, Hangup, Status,
/// Reload. AMI 'Command' and shell execution are deliberately NOT implemented.
/// </summary>
public sealed class AmiClient : BackgroundService
{
    private readonly SmiConfig _cfg;
    private readonly ILogger<AmiClient> _log;
    private readonly ConcurrentDictionary<string, TaskCompletionSource<AmiPacket>> _pending = new();
    private readonly SemaphoreSlim _sendLock = new(1, 1);

    private TcpClient? _tcp;
    private NetworkStream? _stream;
    private int _actionSeq;

    public volatile bool ConnectedAndLoggedIn;
    public volatile bool Reconciled;
    public event Action<AmiPacket>? EventReceived;
    public event Action? ConnectionRestored;
    public event Action? ConnectionLost;

    public AmiClient(SmiConfig cfg, ILogger<AmiClient> log) { _cfg = cfg; _log = log; }

    public bool Ready => ConnectedAndLoggedIn && Reconciled;

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        // The service must start even when AMI is unreachable: readiness stays false and
        // new calls fail closed (spec 5.5), while existing media keeps flowing inside Asterisk.
        var backoff = TimeSpan.FromSeconds(1);
        while (!stopping.IsCancellationRequested)
        {
            try
            {
                await ConnectAndRun(stopping);
                backoff = TimeSpan.FromSeconds(1);
            }
            catch (OperationCanceledException) when (stopping.IsCancellationRequested) { break; }
            catch (Exception ex)
            {
                _log.LogWarning(ex, "AMI connection ended; will retry");
            }
            if (ConnectedAndLoggedIn) ConnectionLost?.Invoke();
            ConnectedAndLoggedIn = false; Reconciled = false;
            await Task.Delay(backoff, stopping);
            backoff = backoff < TimeSpan.FromSeconds(15) ? backoff * 2 : TimeSpan.FromSeconds(15);
        }
    }

    private async Task ConnectAndRun(CancellationToken ct)
    {
        if (_cfg.AmiSecret is null)
        {
            _log.LogError("AMI secret missing (SMI_AMI_SECRET_FILE); AMI will not connect. Calls fail closed.");
            await Task.Delay(TimeSpan.FromSeconds(30), ct);
            return;
        }

        _tcp = new TcpClient();
        await _tcp.ConnectAsync(_cfg.AmiHost, _cfg.AmiPort, ct);
        _stream = _tcp.GetStream();

        using var connection = CancellationTokenSource.CreateLinkedTokenSource(ct);
        // Responses must be consumed while Login is awaiting its ActionID.
        var reader = ReadLoop(connection.Token);
        Task? heartbeat = null;
        try
        {
            var login = await SendAction(new Dictionary<string, string>
            {
                ["Action"] = "Login",
                ["Username"] = _cfg.AmiUsername,
                ["Secret"] = _cfg.AmiSecret,
                ["Events"] = "call,system,user",
            }, connection.Token);
            if (!string.Equals(login?.Get("Response"), "Success", StringComparison.OrdinalIgnoreCase))
            {
                _log.LogError("AMI login rejected or timed out");
                throw new InvalidOperationException("AMI login rejected");
            }

            ConnectedAndLoggedIn = true;
            _log.LogInformation("AMI connected (loopback {Host}:{Port})", _cfg.AmiHost, _cfg.AmiPort);
            ConnectionRestored?.Invoke();
            heartbeat = HeartbeatLoop(connection.Token);
            await reader;
        }
        finally
        {
            connection.Cancel();
            _tcp.Dispose();
            try { await reader; } catch (OperationCanceledException) { } catch (IOException) { }
            if (heartbeat is not null)
            {
                try { await heartbeat; } catch (OperationCanceledException) { }
            }
            _stream = null;
        }
    }

    private async Task HeartbeatLoop(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromSeconds(15), ct);
            var pong = await SendAction(new Dictionary<string, string> { ["Action"] = "Ping" }, CancellationToken.None);
            if (pong is null) _log.LogWarning("AMI heartbeat timeout");
        }
    }

    private async Task ReadLoop(CancellationToken ct)
    {
        var buffer = new byte[8192];
        var sb = new StringBuilder();
        while (!ct.IsCancellationRequested)
        {
            var n = await _stream!.ReadAsync(buffer.AsMemory(0, buffer.Length), ct);
            if (n == 0) throw new IOException("AMI closed the connection");
            sb.Append(Encoding.ASCII.GetString(buffer, 0, n));

            // packets are separated by a blank line; handle several per read
            var text = sb.ToString().Replace("\r\n", "\n");
            int idx;
            while ((idx = text.IndexOf("\n\n", StringComparison.Ordinal)) >= 0)
            {
                var rawPacket = text[..idx];
                text = text[(idx + 2)..];
                var packet = ParsePacket(rawPacket);
                if (packet is not null) Dispatch(packet);
            }
            sb.Clear();
            sb.Append(text);
        }
    }

    private static AmiPacket? ParsePacket(string raw)
    {
        var fields = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        string? eventName = null, responseType = null, actionId = null;
        foreach (var line in raw.Replace("\r\n", "\n").Split('\n'))
        {
            var l = line.TrimEnd('\r');
            if (l.Length == 0) continue;
            var sep = l.IndexOf(':');
            if (sep <= 0) continue;
            var key = l[..sep].Trim();
            var value = l[(sep + 1)..].Trim();
            if (fields.ContainsKey(key)) continue; // tolerate duplicate fields, first wins
            fields[key] = value;
            if (key.Equals("Event", StringComparison.OrdinalIgnoreCase)) eventName = value;
            if (key.Equals("Response", StringComparison.OrdinalIgnoreCase)) responseType = value;
            if (key.Equals("ActionID", StringComparison.OrdinalIgnoreCase)) actionId = value;
        }
        var type = eventName is not null ? "Event" : responseType is not null ? "Response" : "Other";
        if (type == "Other") return null;
        return new AmiPacket(type, eventName, actionId, fields);
    }

    private void Dispatch(AmiPacket packet)
    {
        if (packet.Type == "Response" && packet.ActionId is not null)
        {
            if (_pending.TryRemove(packet.ActionId, out var tcs))
            {
                tcs.TrySetResult(packet);
                return;
            }
        }
        if (packet.Type == "Event" && EventReceived is not null)
        {
            try { EventReceived.Invoke(packet); }
            catch (Exception ex) { _log.LogError(ex, "event handler failed for {Event}", packet.EventName); }
        }
    }

    /// <summary>Send an action and await its response. Returns null on timeout.</summary>
    public async Task<AmiPacket?> SendAction(IReadOnlyDictionary<string, string> fields, CancellationToken ct, TimeSpan? timeout = null)
    {
        var isLogin = fields.TryGetValue("Action", out var action) &&
            string.Equals(action, "Login", StringComparison.OrdinalIgnoreCase);
        if (_stream is null || (!ConnectedAndLoggedIn && !isLogin)) return null;
        var actionId = $"smi-{Environment.ProcessId}-{Interlocked.Increment(ref _actionSeq)}";
        var tcs = new TaskCompletionSource<AmiPacket>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pending[actionId] = tcs;

        var sb = new StringBuilder();
        sb.Append("ActionID: ").Append(actionId).Append("\r\n");
        foreach (var (k, v) in fields) sb.Append(k).Append(": ").Append(v).Append("\r\n");
        sb.Append("\r\n");

        var bytes = Encoding.ASCII.GetBytes(sb.ToString());
        try
        {
            await _sendLock.WaitAsync(ct);
            try { await _stream.WriteAsync(bytes, ct); await _stream.FlushAsync(ct); }
            finally { _sendLock.Release(); }
        }
        catch (Exception)
        {
            _pending.TryRemove(actionId, out _);
            throw;
        }

        try
        {
            var done = await Task.WhenAny(tcs.Task, Task.Delay(timeout ?? TimeSpan.FromSeconds(5), ct));
            return done == tcs.Task ? tcs.Task.Result : null;
        }
        finally
        {
            _pending.TryRemove(actionId, out _);
        }
    }

    public Task<AmiPacket?> SetVar(string channel, string variable, string value, CancellationToken ct) =>
        SendAction(new Dictionary<string, string>
        {
            ["Action"] = "Setvar", ["Channel"] = channel, ["Variable"] = variable, ["Value"] = value,
        }, ct);

    public Task<AmiPacket?> Hangup(string channel, int cause, CancellationToken ct) =>
        SendAction(new Dictionary<string, string>
        {
            ["Action"] = "Hangup", ["Channel"] = channel, ["Cause"] = cause.ToString(),
        }, ct);

    public Task<AmiPacket?> Reload(string module, CancellationToken ct) =>
        SendAction(new Dictionary<string, string> { ["Action"] = "Reload", ["Module"] = module }, ct);

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        await base.StopAsync(cancellationToken);
        _tcp?.Close();
    }
}
