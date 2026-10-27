namespace Smi.Control.Calls;

public enum CallState { Pending, Connecting, Connected, Ended }

public enum EndReason
{
    Completed, Declined, CallerCancelled, NoAnswer, Busy, Unavailable,
    Expired, NetworkLost, ServerRestart, SetupFailed, AccountDisabled,
}

/// <summary>
/// Server-side call state machine (spec 6.1): Pending → Connecting → Connected → Ended.
/// Direct Pending→Connected is allowed only with valid PBX evidence. Downgrade is forbidden.
/// Ended is terminal — late events, duplicate pushes or a later "ready" never revive it.
/// </summary>
public static class CallStateMachine
{
    public static bool CanTransition(CallState from, CallState to) => (from, to) switch
    {
        (CallState.Pending, CallState.Connecting) => true,
        (CallState.Pending, CallState.Connected) => true,   // PBX evidence only
        (CallState.Pending, CallState.Ended) => true,
        (CallState.Connecting, CallState.Connected) => true,
        (CallState.Connecting, CallState.Ended) => true,
        (CallState.Connected, CallState.Ended) => true,
        _ => false,
    };

    public static void EnsureTransition(CallState from, CallState to)
    {
        if (!CanTransition(from, to))
            throw new InvalidTransitionException(from, to);
    }

    public static bool IsTerminal(CallState s) => s == CallState.Ended;
}

public sealed class InvalidTransitionException : Exception
{
    public CallState From { get; }
    public CallState To { get; }
    public InvalidTransitionException(CallState from, CallState to)
        : base($"invalid call transition {from} -> {to}")
    {
        From = from; To = to;
    }
}

/// <summary>Outcome of an admission attempt (kept explicit — no exceptions for expected flows).</summary>
public enum AdmissionResult { Created, DuplicateAttempt, Busy, UnknownOrDisabledCallee, SelfCall, InvalidInput }
