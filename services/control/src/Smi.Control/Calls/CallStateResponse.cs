namespace Smi.Control.Calls;

/// <summary>The public wire contract; database/PBX bookkeeping never leaves this boundary.</summary>
public sealed record CallStateResponse(
    string CallId, string AttemptId, string Caller, string Callee, int DeviceGeneration,
    string State, long Revision, DateTime CreatedAt, DateTime ExpiresAt,
    DateTime? AcceptedAt, DateTime? ConnectedAt, DateTime? EndedAt, string? EndReason,
    DateTime ServerTime)
{
    public static CallStateResponse? From(CallRow? call) => call is null ? null : new(
        call.CallId, call.AttemptId, call.CallerExt, call.CalleeExt, call.CalleeDeviceGeneration,
        call.State.ToString(), call.Revision, call.CreatedAtUtc, call.DeadlineUtc,
        call.AcceptedAtUtc, call.ConnectedAtUtc, call.EndedAtUtc, call.EndReason?.ToString(),
        DateTime.UtcNow);
}
